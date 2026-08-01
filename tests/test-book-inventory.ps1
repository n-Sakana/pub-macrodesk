param(
    [string]$BookPath,
    [string]$ProductRoot
)

# What a workbook carries besides its VBA code. The tool never changes any
# of it, so the only thing that matters is that it is found, named, and
# reported honestly - including reporting an absence as an absence.

$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

if ([string]::IsNullOrEmpty($ProductRoot)) {
    $ProductRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $ProductRoot 'testdata\input_win32_sleep.xlsm'
}

$repoRoot = (Resolve-Path -LiteralPath $ProductRoot).Path
$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$srcDir = Join-Path $repoRoot 'src'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$libDir = Join-Path $repoRoot 'lib'
$corePath = Join-Path $libDir 'Microsoft.Web.WebView2.Core.dll'
$wpfPath = Join-Path $libDir 'Microsoft.Web.WebView2.Wpf.dll'
[Reflection.Assembly]::LoadFrom($corePath) | Out-Null
[Reflection.Assembly]::LoadFrom($wpfPath) | Out-Null

$sourceFiles = Get-ChildItem -LiteralPath $srcDir -Filter '*.cs' |
    Sort-Object -Property Name
$combined = ($sourceFiles | ForEach-Object {
    [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
}) -join "`n"
$usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
$usings = [regex]::Matches($combined, $usingPattern) |
    ForEach-Object { $_.Value.Trim() } |
    Sort-Object -Unique
$body = $combined -replace $usingPattern, ''
$source = ($usings -join "`n") + "`n`n" + $body

$references = @(
    [System.Windows.Window].Assembly.Location
    [System.Windows.UIElement].Assembly.Location
    [System.Windows.DependencyObject].Assembly.Location
    [System.Xaml.XamlReader].Assembly.Location
    'Microsoft.CSharp'
    'System.Drawing'
    'System.Web.Extensions'
    'System.IO.Compression',
    'System.IO.Compression.FileSystem'
    $corePath
    $wpfPath
)
Add-Type -TypeDefinition $source `
    -ReferencedAssemblies $references `
    -Language CSharp

$project = [MacroStudio.BookIO]::ReadProject($resolvedBookPath)
$bytes = [IO.File]::ReadAllBytes($resolvedBookPath)
$inventory = [MacroStudio.BookInventoryReader]::Read(
    $resolvedBookPath,
    $bytes,
    $project)

# ---- the file's own facts ----

$expectedHash = (Get-FileHash -LiteralPath $resolvedBookPath `
    -Algorithm SHA256).Hash.ToLowerInvariant()

Assert-True ($inventory.Sha256 -ceq $expectedHash) `
    ("The recorded hash must be this file's hash: " + $inventory.Sha256)
Assert-True ($inventory.SizeBytes -eq $bytes.LongLength) `
    'The recorded size must be this file''s size.'
Assert-True (-not [string]::IsNullOrEmpty($inventory.ModifiedUtc)) `
    'The workbook''s last write time must be recorded for the baseline.'

# ---- references come out of the project, not out of a guess ----

Assert-True ($inventory.References.Count -gt 0) `
    'A VBA project always references at least one library.'
Assert-True (@($inventory.References) -contains 'stdole') `
    ('The standard OLE reference must be listed: ' +
        ($inventory.References -join ', '))
Assert-True (
    @($inventory.References | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0
) 'A reference name must never be blank.'

# ---- an absence is reported, not omitted ----

Assert-True ($inventory.Complete) `
    'A readable package must be reported as completely read.'
Assert-True ($inventory.ActiveXCount -ge 0) `
    'The ActiveX count must be a real count.'
Assert-True ($inventory.ExternalLinkCount -ge 0) `
    'The external link count must be a real count.'

# ---- nothing that belongs to the owner is copied out ----
# A connection carries servers, paths and sometimes credentials. Only its
# name is taken, so the inventory can never become a place a secret leaks.

foreach ($name in @($inventory.Connections)) {
    Assert-True (
        $name -notmatch 'Provider=|Data Source=|Password=|User ID=|https?://|\\\\'
    ) ('A connection string must never reach the inventory: ' + $name)
}
foreach ($name in @($inventory.References)) {
    Assert-True ($name -notmatch '[\\/]|\.dll$|\.tlb$') `
        ('A reference path must never reach the inventory: ' + $name)
}

# ---- a workbook that is not a package still reads what it can ----

$notAPackage = [MacroStudio.BookInventoryReader]::Read(
    $resolvedBookPath,
    [byte[]]@(1, 2, 3, 4),
    $project)

Assert-True (-not $notAPackage.Complete) `
    'A file that could not be opened as a package must say so.'
Assert-True ($notAPackage.References.Count -gt 0) `
    'The project''s references still read even when the package does not.'

# ---- no project at all ----

$noProject = [MacroStudio.BookInventoryReader]::Read(
    $resolvedBookPath,
    $bytes,
    $null)

Assert-True (-not $noProject.Complete -and $noProject.References.Count -eq 0) `
    'Without a project there are no references to report, and it must say so.'
Assert-True ($noProject.Sha256 -ceq $expectedHash) `
    'The file''s own facts do not depend on the project parsing.'

Write-Output 'test-book-inventory: PASS'
Write-Output (
    'hash/size/mtime recorded, references=' +
    $inventory.References.Count +
    ', connections=' + $inventory.Connections.Count +
    ', activeX=' + $inventory.ActiveXCount +
    ', externalLinks=' + $inventory.ExternalLinkCount +
    ', powerQuery=' + $inventory.HasPowerQuery +
    ', barcodeFonts=' + $inventory.BarcodeFonts.Count +
    '; no connection string or library path copied out')
