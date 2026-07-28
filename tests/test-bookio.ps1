param(
    [string]$BookPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ErrorCode {
    param(
        [ScriptBlock]$Action,
        [string]$ExpectedCode
    )

    $actualCode = ''
    try {
        & $Action
    } catch [MacroDesk.MacroDeskException] {
        $actualCode = $_.Exception.ErrorCode
    }

    Assert-True ($actualCode -eq $ExpectedCode) `
        "Expected $ExpectedCode, got $actualCode."
}

function Get-EngineSource {
    $names = @(
        '05_Ole2.cs',
        '06_VbaCompression.cs',
        '07_VbaProject.cs',
        '08_BookIO.cs'
    )
    $combined = ($names | ForEach-Object {
        $path = Join-Path (Join-Path $PSScriptRoot '..\src') $_
        [IO.File]::ReadAllText(
            (Resolve-Path -LiteralPath $path),
            [Text.Encoding]::UTF8)
    }) -join "`n"

    $usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
    $usings = [regex]::Matches($combined, $usingPattern) |
        ForEach-Object { $_.Value.Trim() } |
        Sort-Object -Unique
    $body = $combined -replace $usingPattern, ''
    return ($usings -join "`n") + "`n`n" + $body
}

function New-ZipWithEntry {
    param(
        [string]$Path,
        [string]$EntryName,
        [byte[]]$Content
    )

    $archive = [IO.Compression.ZipFile]::Open(
        $Path,
        [IO.Compression.ZipArchiveMode]::Create)
    try {
        $entry = $archive.CreateEntry($EntryName)
        $stream = $entry.Open()
        try {
            $stream.Write($Content, 0, $Content.Length)
        } finally {
            $stream.Dispose()
        }
    } finally {
        $archive.Dispose()
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$references = @(
    'System.IO.Compression',
    'System.IO.Compression.FileSystem'
)
Add-Type -TypeDefinition (Get-EngineSource) `
    -ReferencedAssemblies $references `
    -Language CSharp

$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$content = [MacroDesk.BookIO]::ReadVbaProjectBytes($resolvedBookPath)
Assert-True $content.IsZip 'Workbook was not marked as ZIP.'
Assert-True ($content.Extension -eq '.xlsm') 'Workbook extension mismatch.'
Assert-True ($content.VbaProjectBytes.Length -eq 17920) `
    'vbaProject.bin length mismatch.'

$project = [MacroDesk.BookIO]::ReadProject($resolvedBookPath)
Assert-True ($project.Modules.Count -eq 6) 'Project module count mismatch.'
Assert-True ($project.FilePath -eq $resolvedBookPath) `
    'Project file path mismatch.'

$exclusive = [IO.File]::Open(
    $resolvedBookPath,
    [IO.FileMode]::Open,
    [IO.FileAccess]::Read,
    [IO.FileShare]::None)
$exclusive.Dispose()

$testdataPath = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$suffix = [Guid]::NewGuid().ToString('N')
$nestedPath = Join-Path $testdataPath ("bookio-nested-$suffix.xlam")
$emptyPath = Join-Path $testdataPath ("bookio-empty-$suffix.xlsm")
$invalidXlsbPath = Join-Path $testdataPath ("bookio-invalid-$suffix.xlsb")
$missingPath = Join-Path $testdataPath ("bookio-missing-$suffix.xlsm")

foreach ($path in @(
    $nestedPath,
    $emptyPath,
    $invalidXlsbPath,
    $missingPath)) {
    $fullPath = [IO.Path]::GetFullPath($path)
    Assert-True (
        $fullPath.StartsWith(
            $testdataPath + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) `
        'Temporary test path is outside testdata.'
}

try {
    New-ZipWithEntry `
        $nestedPath `
        'custom/location/vbaProject.bin' `
        $content.VbaProjectBytes
    $nested = [MacroDesk.BookIO]::ReadVbaProjectBytes($nestedPath)
    Assert-True (
        $nested.VbaProjectBytes.Length -eq
        $content.VbaProjectBytes.Length) `
        'Name-only ZIP lookup returned the wrong data.'
    $nestedProject = [MacroDesk.BookIO]::ReadProject($nestedPath)
    Assert-True ($nestedProject.Modules.Count -eq 6) `
        '.xlam project extraction failed.'

    [byte[]]$dummy = 0x41
    New-ZipWithEntry $emptyPath 'custom/location/dummy.txt' $dummy
    Assert-ErrorCode {
        [MacroDesk.BookIO]::ReadVbaProjectBytes($emptyPath)
    } 'E-ATTACH-03'

    New-ZipWithEntry `
        $invalidXlsbPath `
        'custom/location/vbaProject.bin' `
        $dummy
    Assert-ErrorCode {
        [MacroDesk.BookIO]::ReadProject($invalidXlsbPath)
    } 'E-ATTACH-05'

    Assert-ErrorCode {
        [MacroDesk.BookIO]::ReadVbaProjectBytes(
            [IO.Path]::ChangeExtension($resolvedBookPath, '.xls'))
    } 'E-ATTACH-01'

    Assert-ErrorCode {
        [MacroDesk.BookIO]::ReadVbaProjectBytes(
            [IO.Path]::ChangeExtension($resolvedBookPath, '.txt'))
    } 'E-ATTACH-01'

    Assert-ErrorCode {
        [MacroDesk.BookIO]::ReadVbaProjectBytes($missingPath)
    } 'E-ATTACH-02'
} finally {
    foreach ($path in @($nestedPath, $emptyPath, $invalidXlsbPath)) {
        if ([IO.File]::Exists($path)) {
            [IO.File]::Delete($path)
        }
    }
}

Write-Output 'test-bookio: PASS'
Write-Output (
    'book={0}, vbaProject={1}, modules={2}, exclusiveReopen=ok' -f `
    (Get-Item -LiteralPath $resolvedBookPath).Length,
    $content.VbaProjectBytes.Length,
    $project.Modules.Count)
