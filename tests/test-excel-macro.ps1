param(
    [Parameter(Mandatory = $true)]
    [string]$BookPath,
    [string]$MacroName = 'TimerUtils.Test'
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-InsideDirectory {
    param(
        [string]$Path,
        [string]$Directory
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar)
    $prefix = $fullDirectory + [IO.Path]::DirectorySeparatorChar
    Assert-True (
        $fullPath.StartsWith(
            $prefix,
            [StringComparison]::OrdinalIgnoreCase)) `
        "Test path is outside the expected directory: $fullPath"
}

if (-not ('MacroDesk.Tests.NativeWindow' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace MacroDesk.Tests
{
    public static class NativeWindow
    {
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(
            IntPtr window,
            out uint processId);
    }
}
'@
}

$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$resolvedBook = (Resolve-Path -LiteralPath $BookPath).Path
Assert-InsideDirectory $resolvedBook $testdataRoot
Assert-True (
    [string]::Equals(
        [IO.Path]::GetExtension($resolvedBook),
        '.xlsm',
        [StringComparison]::OrdinalIgnoreCase)) `
    'Excel macro test requires an xlsm workbook.'

$copyPath = Join-Path $testdataRoot (
    'excel-macro-' +
    [Guid]::NewGuid().ToString('N') +
    '.xlsm')
Assert-InsideDirectory $copyPath $testdataRoot
[IO.File]::Copy($resolvedBook, $copyPath, $false)

$existingIds = @{}
foreach ($process in @(Get-Process -Name EXCEL -ErrorAction SilentlyContinue)) {
    $existingIds[$process.Id] = $true
}

$excel = $null
$workbook = $null
$ownedProcessId = 0
$ownsProcess = $false
try {
    $excel = New-Object -ComObject Excel.Application
    $windowHandle = [IntPtr][int64]$excel.Hwnd
    [uint32]$processId = 0
    [void][MacroDesk.Tests.NativeWindow]::GetWindowThreadProcessId(
        $windowHandle,
        [ref]$processId)
    $ownedProcessId = [int]$processId
    Assert-True ($ownedProcessId -gt 0) `
        'Could not identify the Excel test process.'
    Assert-True (-not $existingIds.ContainsKey($ownedProcessId)) `
        'Excel automation connected to a pre-existing process.'
    $ownsProcess = $true

    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.EnableEvents = $false
    $excel.AutomationSecurity = 1
    $workbook = $excel.Workbooks.Open($copyPath, 0, $true)
    Assert-True ($null -ne $workbook) `
        'Excel did not open the rebuilt workbook.'
    Assert-True ($workbook.ReadOnly) `
        'Excel test workbook was not opened read-only.'

    $qualifiedMacro = (
        "'" +
        $workbook.Name.Replace("'", "''") +
        "'!" +
        $MacroName)
    [void]$excel.Run($qualifiedMacro)

    Write-Output 'test-excel-macro: PASS'
    Write-Output ('book=' + [IO.Path]::GetFileName($resolvedBook))
    Write-Output ('macro=' + $MacroName)
    Write-Output ('excelPid=' + $ownedProcessId)
} finally {
    if ($null -ne $workbook) {
        try {
            $workbook.Close($false)
        } catch {
        }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject(
            $workbook)
        $workbook = $null
    }
    if ($null -ne $excel) {
        if ($ownsProcess) {
            try {
                $excel.Quit()
            } catch {
            }
        }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject(
            $excel)
        $excel = $null
    }

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()

    if ($ownsProcess -and $ownedProcessId -gt 0) {
        for ($attempt = 0; $attempt -lt 100; $attempt++) {
            if ($null -eq (
                Get-Process -Id $ownedProcessId `
                    -ErrorAction SilentlyContinue)) {
                break
            }
            Start-Sleep -Milliseconds 50
        }
        $leftover = Get-Process -Id $ownedProcessId `
            -ErrorAction SilentlyContinue
        if ($null -ne $leftover) {
            Stop-Process -Id $ownedProcessId -Force
            [void]$leftover.WaitForExit(5000)
        }
    }

    Assert-InsideDirectory $copyPath $testdataRoot
    if ([IO.File]::Exists($copyPath)) {
        [IO.File]::Delete($copyPath)
    }
}
