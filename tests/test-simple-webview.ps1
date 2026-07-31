param(
    [string]$BookPath,
    [string]$ProductRoot
)

# The short way, driven in the real runtime, twice: one paste and one
# module at a time. Both have to reach a rebuilt workbook, because the
# short way is not a smaller job - only a shorter screen path.

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

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
}
if ([string]::IsNullOrEmpty($ProductRoot)) {
    $ProductRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$repoRoot = (Resolve-Path -LiteralPath $ProductRoot).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$libDir = Join-Path $repoRoot 'lib'
$cacheDir = Join-Path $testdataRoot (
    'simple-cache-' + [Guid]::NewGuid().ToString('N'))
Assert-InsideDirectory $cacheDir $testdataRoot

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$env:Path = $libDir + [IO.Path]::PathSeparator + $env:Path
$corePath = Join-Path $libDir 'Microsoft.Web.WebView2.Core.dll'
$wpfPath = Join-Path $libDir 'Microsoft.Web.WebView2.Wpf.dll'
[Reflection.Assembly]::LoadFrom($corePath) | Out-Null
[Reflection.Assembly]::LoadFrom($wpfPath) | Out-Null

$sourceFiles = Get-ChildItem -LiteralPath (
    Join-Path $repoRoot 'src') -Filter '*.cs' |
    Sort-Object -Property Name
$smokeSource = Join-Path $PSScriptRoot 'SimpleModeSmoke.cs'
$combined = (@($sourceFiles.FullName) + @($smokeSource) |
    ForEach-Object {
        [IO.File]::ReadAllText($_, [Text.Encoding]::UTF8)
    }) -join "`n"

$usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
$usings = [regex]::Matches($combined, $usingPattern) |
    ForEach-Object { $_.Value.Trim() } |
    Sort-Object -Unique
$source = ($usings -join "`n") + "`n`n" +
    ($combined -replace $usingPattern, '')

Add-Type -TypeDefinition $source -ReferencedAssemblies @(
    [System.Windows.Window].Assembly.Location
    [System.Windows.UIElement].Assembly.Location
    [System.Windows.DependencyObject].Assembly.Location
    [System.Xaml.XamlReader].Assembly.Location
    'Microsoft.CSharp'
    'System.Drawing'
    'System.Web.Extensions'
    'System.IO.Compression'
    'System.IO.Compression.FileSystem'
    $corePath
    $wpfPath
) -Language CSharp

$runFolders = @()
try {
    try {
        $rawResult = [MacroStudio.Tests.SimpleModeSmoke]::Run(
            $repoRoot,
            $cacheDir,
            $resolvedBookPath)
    } catch {
        throw $_.Exception.ToString()
    }

    $result = $rawResult | ConvertFrom-Json
    $opening = $result.opening | ConvertFrom-Json
    $simpleWord = -join @([char]0x7C21, [char]0x6613)

    # ---- the opening screen ----
    Assert-True ($opening.starters -eq 1) `
        ("The short way must be offered once: " + $opening.starters)
    Assert-True ($opening.modes -eq 2) `
        'The two main choices must stay.'
    Assert-True (-not $opening.primary) `
        'The short way must not be a primary button.'
    Assert-True (([string]$opening.label).IndexOf($simpleWord) -ge 0) `
        ("The short way must name itself: " + $opening.label)

    # Words the short way must never show. They belong to the detailed
    # screens; someone starting here has no use for them.
    $jargon = @(
        (-join @([char]0x3072, [char]0x306A, [char]0x5F62)),
        (-join @([char]0x51FA, [char]0x529B, [char]0x6307, [char]0x793A)),
        (-join @([char]0x4F9D, [char]0x983C, [char]0x0049, [char]0x0044)))

    foreach ($name in @('whole', 'split')) {
        $phase = $result.$name | ConvertFrom-Json
        $request = $phase.request | ConvertFrom-Json
        $requestScreen = $phase.requestScreen | ConvertFrom-Json
        $review = $phase.review | ConvertFrom-Json
        $built = $phase.built | ConvertFrom-Json

        Assert-True ([bool]$phase.startedOnBook) `
            "$name : the short way must open on the workbook screen."

        # ---- one box, one option, nothing else ----
        Assert-True ($requestScreen.boxes -eq 1) `
            "$name : there must be exactly one box to write in."
        Assert-True ($requestScreen.options -eq 1) `
            ("$name : exactly one option belongs here: " +
                $requestScreen.options)
        Assert-True ($requestScreen.disclosures -eq 0) `
            "$name : the short way hides nothing behind a disclosure."
        Assert-True ($requestScreen.presetCards -eq 0) `
            "$name : the short way shows no purposes to choose from."
        foreach ($word in $jargon) {
            Assert-True (
                ([string]$requestScreen.text).IndexOf($word) -lt 0) `
                ("$name : the short way showed " + $word)
        }

        # ---- the request is the same request ----
        Assert-True ([bool]$request.carriesWhatWasWritten) `
            "$name : what the user wrote must reach the request."
        Assert-True ([bool]$request.carriesTheId) `
            "$name : the request must carry its id, as always."
        if ($name -eq 'split') {
            Assert-True ([bool]$request.carriesPartRule) `
                'The long-code option must ask for one module per reply.'
        } else {
            Assert-True (-not $request.carriesPartRule) `
                'A normal run must not ask for parts.'
        }
        Assert-True (
            -not [string]::IsNullOrEmpty([string]$request.runFolder)) `
            "$name : the run folder must exist."
        $runFolders += [string]$request.runFolder

        # ---- the review screen shows the account, and nothing else ----
        Assert-True ($review.diffTables -eq 0) `
            "$name : the short way shows no diff."
        Assert-True ($review.moduleItems -eq 0) `
            "$name : the short way shows no module list."
        Assert-True ($review.disclosures -eq 0) `
            "$name : the short way hides nothing here either."
        Assert-True ($review.editButtons -eq 0) `
            "$name : the short way offers no manual fix."
        Assert-True (
            ([string]$review.text).IndexOf(
                (-join @([char]0x76F4, [char]0x3057))) -ge 0) `
            "$name : the review screen must say what was changed."

        # ---- and it builds ----
        Assert-True ([bool]$built.success) `
            "$name : the short way must reach a rebuilt workbook."
        Assert-True (
            -not [string]::IsNullOrEmpty([string]$built.outputPath)) `
            "$name : the build must name the file it wrote."
        Assert-True ([IO.File]::Exists([string]$built.outputPath)) `
            ("$name : the rebuilt workbook is missing: " +
                $built.outputPath)
        Assert-True ($built.written -ge 2) `
            ("$name : both modules must be written: " + $built.written)
    }

    Write-Output 'test-simple-webview: PASS'
    Write-Output (
        'one paste and module-by-module both reached a rebuilt workbook')
} finally {
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
    foreach ($folder in $runFolders) {
        if ($folder -and [IO.Directory]::Exists($folder)) {
            Assert-InsideDirectory $folder $testdataRoot
            [IO.Directory]::Delete($folder, $true)
        }
    }
    if ([IO.Directory]::Exists($cacheDir)) {
        Assert-InsideDirectory $cacheDir $testdataRoot
        try {
            [IO.Directory]::Delete($cacheDir, $true)
        } catch {
        }
    }
}
