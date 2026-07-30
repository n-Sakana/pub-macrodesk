param()

# Observation test: what does the engine do with a workbook whose FILE
# is password-encrypted (Excel "Password to open")? Creates the
# encrypted copy with real Excel, then attaches it through BookIO.

$ErrorActionPreference = 'Stop'
$repo = 'C:\repos\pub\macrostudio'
$scratch = Split-Path -Parent $MyInvocation.MyCommand.Path
$plain = Join-Path $repo 'testdata\input_win32_sleep.xlsm'
$encrypted = Join-Path $scratch 'demo\encrypted_copy.xlsm'

if (Test-Path $encrypted) { Remove-Item $encrypted -Force }

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
try {
    $book = $excel.Workbooks.Open($plain, 0, $true)
    # 52 = xlOpenXMLWorkbookMacroEnabled
    $book.SaveAs($encrypted, 52, 'test-password-123')
    $book.Close($false)
} finally {
    $excel.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
}

Write-Output ("encrypted copy: {0} ({1} bytes)" -f `
    $encrypted, (Get-Item $encrypted).Length)

# First bytes: an encrypted workbook is an OLE2 compound file, not a zip.
$bytes = [IO.File]::ReadAllBytes($encrypted)
Write-Output ("first bytes: {0}" -f `
    (($bytes[0..7] | ForEach-Object { $_.ToString('X2') }) -join ' '))

function Get-EngineSource {
    $names = @('05_Ole2.cs', '06_VbaCompression.cs',
        '07_VbaProject.cs', '08_BookIO.cs')
    $combined = ($names | ForEach-Object {
        [IO.File]::ReadAllText(
            (Join-Path (Join-Path $repo 'src') $_),
            [Text.Encoding]::UTF8)
    }) -join "`n"
    $usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
    $usings = [regex]::Matches($combined, $usingPattern) |
        ForEach-Object { $_.Value.Trim() } | Sort-Object -Unique
    $body = $combined -replace $usingPattern, ''
    return ($usings -join "`n") + "`n`n" + $body
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -TypeDefinition (Get-EngineSource) `
    -ReferencedAssemblies @('System.IO.Compression',
        'System.IO.Compression.FileSystem') `
    -Language CSharp

try {
    $project = [MacroStudio.BookIO]::ReadProject($encrypted)
    Write-Output ("READ SUCCEEDED?! modules={0} warnings={1}" -f `
        $project.Modules.Count, $project.HasReadWarnings)
} catch {
    $inner = $_.Exception
    while ($inner.InnerException) { $inner = $inner.InnerException }
    Write-Output ("read failed as expected:")
    Write-Output ("  type: {0}" -f $inner.GetType().FullName)
    if ($inner -is [MacroStudio.MacroStudioException]) {
        Write-Output ("  code: {0}" -f $inner.Code)
    }
    Write-Output ("  message: {0}" -f $inner.Message)
}
