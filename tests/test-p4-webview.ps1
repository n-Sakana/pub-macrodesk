param(
    [string]$ScreenshotPath
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

function Get-Number {
    param(
        [object]$Value
    )

    return [Convert]::ToDouble(
        $Value,
        [Globalization.CultureInfo]::InvariantCulture)
}

function Assert-Near {
    param(
        [object]$Actual,
        [double]$Expected,
        [double]$Tolerance,
        [string]$Message
    )

    $number = Get-Number $Actual
    Assert-True (
        [Math]::Abs($number - $Expected) -le $Tolerance) `
        "$Message Actual=$number Expected=$Expected"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$libDir = Join-Path $repoRoot 'lib'
$cacheDir = Join-Path $testdataRoot (
    'p4-webview-cache-' + [Guid]::NewGuid().ToString('N'))
$preserveScreenshot = -not [string]::IsNullOrEmpty($ScreenshotPath)

if ([string]::IsNullOrEmpty($ScreenshotPath)) {
    $ScreenshotPath = Join-Path $testdataRoot (
        'p4-layout-' + [Guid]::NewGuid().ToString('N') + '.png')
}

$fullScreenshotPath = [IO.Path]::GetFullPath($ScreenshotPath)
Assert-InsideDirectory $cacheDir $testdataRoot
Assert-InsideDirectory $fullScreenshotPath $testdataRoot
Assert-True (-not [IO.File]::Exists($fullScreenshotPath)) `
    "Screenshot path already exists: $fullScreenshotPath"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Web.Extensions

$env:Path = $libDir + [IO.Path]::PathSeparator + $env:Path
$corePath = Join-Path $libDir 'Microsoft.Web.WebView2.Core.dll'
$wpfPath = Join-Path $libDir 'Microsoft.Web.WebView2.Wpf.dll'
[Reflection.Assembly]::LoadFrom($corePath) | Out-Null
[Reflection.Assembly]::LoadFrom($wpfPath) | Out-Null

$smokeSource = Join-Path $PSScriptRoot 'P4VisualSmoke.cs'
$source = [IO.File]::ReadAllText(
    $smokeSource,
    [Text.Encoding]::UTF8)
$references = @(
    [System.Windows.Window].Assembly.Location
    [System.Windows.UIElement].Assembly.Location
    [System.Windows.DependencyObject].Assembly.Location
    [System.Xaml.XamlReader].Assembly.Location
    'System.Web.Extensions'
    $corePath
    $wpfPath
)

Add-Type -TypeDefinition $source `
    -ReferencedAssemblies $references `
    -Language CSharp

try {
    try {
        $rawResult = [MacroDesk.Tests.P4VisualSmoke]::Run(
            $repoRoot,
            $cacheDir,
            $fullScreenshotPath)
    } catch {
        throw $_.Exception.ToString()
    }

    $result = $rawResult | ConvertFrom-Json
    $initial = $result.initial | ConvertFrom-Json
    $collapsed = $result.collapsed | ConvertFrom-Json
    $errorState = $result.error | ConvertFrom-Json
    $preserved = $result.preserved | ConvertFrom-Json

    Assert-True ($initial.ready -eq 'complete') `
        'P4 document did not finish loading.'
    Assert-Near $initial.viewport.w 1366 0.5 `
        'Viewport width mismatch.'
    Assert-Near $initial.viewport.h 768 0.5 `
        'Viewport height mismatch.'
    Assert-True (
        (Get-Number $initial.documentSize.w) -le
        (Get-Number $initial.viewport.w)) `
        'P4 layout has horizontal document scroll.'
    Assert-True (
        (Get-Number $initial.documentSize.h) -le
        (Get-Number $initial.viewport.h)) `
        'P4 layout has vertical document scroll.'
    Assert-Near $initial.progress.h 48 0.5 `
        'Progress height mismatch.'
    Assert-Near $initial.modules.w 341.5 1 `
        'Module column is not 25 percent wide.'
    Assert-Near $initial.modules.h 720 0.5 `
        'Module column height mismatch.'
    Assert-Near $initial.lecture.h 150 0.5 `
        'Expanded lecture height mismatch.'
    Assert-Near $initial.main.h 570 0.5 `
        'Expanded main height mismatch.'
    Assert-True ((Get-Number $initial.diff.w) -gt 900) `
        'Step 3 diff width is too small.'
    Assert-True ($initial.diffColumns -eq 2) `
        'Step 3 must show two diff columns.'
    Assert-True ($initial.diffRows -gt 0) `
        'Step 3 diff must contain rows.'
    Assert-True ($initial.badges.pending -ge 1) `
        'Pending badge is missing.'
    Assert-True ($initial.badges.changed -ge 1) `
        'Changed badge is missing.'
    Assert-True ($initial.badges.unchanged -ge 1) `
        'Unchanged badge is missing.'
    Assert-True ($initial.badges.excluded -ge 1) `
        'Excluded badge is missing.'
    Assert-True ($initial.badges.written -ge 1) `
        'Written badge is missing.'
    Assert-True ($initial.branch -eq 'L3-3') `
        'Step 3 lecture branch mismatch.'
    Assert-True ($initial.step -eq 3) `
        'Demo screen did not open at step 3.'
    Assert-True ($initial.step4 -eq $true) `
        'Changed modules must enable step 4.'

    Assert-True ($collapsed.collapsed -eq $true) `
        'Lecture did not enter the collapsed state.'
    Assert-Near $collapsed.lecture.h 28 0.5 `
        'Collapsed lecture height mismatch.'
    Assert-Near $collapsed.main.h 692 0.5 `
        'Collapsed main height mismatch.'

    Assert-True ($errorState.collapsed -eq $false) `
        'A new error must expand the lecture.'
    Assert-True ($errorState.error -eq $true) `
        'Error lecture style is missing.'
    Assert-True ($errorState.branch -eq 'L-E*') `
        'Error lecture branch mismatch.'
    Assert-Near $errorState.lecture.h 150 0.5 `
        'Error-expanded lecture height mismatch.'

    Assert-True ($preserved.step -eq 3) `
        'Step navigation did not return to step 3.'
    Assert-True ($preserved.selected -eq 'Main') `
        'Step navigation did not preserve module selection.'
    Assert-True ($preserved.step4 -eq $true) `
        'Step navigation did not preserve changed modules.'
    Assert-True ([IO.File]::Exists($fullScreenshotPath)) `
        'P4 screenshot was not created.'
} finally {
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
    Assert-InsideDirectory $cacheDir $testdataRoot
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        if (-not [IO.Directory]::Exists($cacheDir)) {
            break
        }
        try {
            [IO.Directory]::Delete($cacheDir, $true)
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (
        -not $preserveScreenshot -and
        [IO.File]::Exists($fullScreenshotPath)) {
        [IO.File]::Delete($fullScreenshotPath)
    }
}

Assert-True (-not [IO.Directory]::Exists($cacheDir)) `
    "WebView test cache could not be removed: $cacheDir"
if (-not $preserveScreenshot) {
    Assert-True (-not [IO.File]::Exists($fullScreenshotPath)) `
        "Temporary screenshot could not be removed: $fullScreenshotPath"
}

Write-Output 'test-p4-webview: PASS'
Write-Output (
    'viewport=1366x768, progress=48, modules=25%, ' +
    'lecture=150/28, main=570/692, no-horizontal-scroll')
if ($preserveScreenshot) {
    Write-Output ('screenshot=' + $fullScreenshotPath)
} else {
    Write-Output 'screenshot=validated-and-removed'
}
