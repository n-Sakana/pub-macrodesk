param(
    [string]$PresetScreenshotPath,
    [string]$GuidedScreenshotPath,
    [string]$ErrorScreenshotPath
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

function Get-JsonProperty {
    param(
        [object]$Container,
        [string]$Name
    )

    $property = $Container.PSObject.Properties[$Name]
    Assert-True ($null -ne $property) `
        "JSON property was not found: $Name"
    return $property.Value | ConvertFrom-Json
}

function Assert-Guided {
    param(
        [object]$Metric,
        [string]$ExpectedTarget,
        [string]$Label
    )

    Assert-True ($Metric.guided -eq 1) `
        "$Label must have exactly one guided target."
    Assert-True (
        [string]$Metric.guidedAction -match $ExpectedTarget) `
        "$Label guided target mismatch: $($Metric.guidedAction)"
    Assert-True (-not $Metric.horizontal) `
        "$Label has document-level horizontal scroll."
    Assert-True (
        [string]$Metric.font -match 'Noto Sans JP') `
        "$Label does not use the bundled Japanese UI font."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$libDir = Join-Path $repoRoot 'lib'
$cacheDir = Join-Path $testdataRoot (
    'p8-webview-cache-' + [Guid]::NewGuid().ToString('N'))
$preserveScreenshots =
    -not [string]::IsNullOrEmpty($PresetScreenshotPath) -and
    -not [string]::IsNullOrEmpty($GuidedScreenshotPath) -and
    -not [string]::IsNullOrEmpty($ErrorScreenshotPath)

if ([string]::IsNullOrEmpty($PresetScreenshotPath)) {
    $PresetScreenshotPath = Join-Path $testdataRoot (
        'p8-preset-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($GuidedScreenshotPath)) {
    $GuidedScreenshotPath = Join-Path $testdataRoot (
        'p8-guided-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($ErrorScreenshotPath)) {
    $ErrorScreenshotPath = Join-Path $testdataRoot (
        'p8-error-' + [Guid]::NewGuid().ToString('N') + '.png')
}

$presetScreenshot = [IO.Path]::GetFullPath($PresetScreenshotPath)
$guidedScreenshot = [IO.Path]::GetFullPath($GuidedScreenshotPath)
$errorScreenshot = [IO.Path]::GetFullPath($ErrorScreenshotPath)
Assert-InsideDirectory $cacheDir $testdataRoot
Assert-InsideDirectory $presetScreenshot $testdataRoot
Assert-InsideDirectory $guidedScreenshot $testdataRoot
Assert-InsideDirectory $errorScreenshot $testdataRoot
foreach ($path in @(
    $presetScreenshot,
    $guidedScreenshot,
    $errorScreenshot)) {
    Assert-True (-not [IO.File]::Exists($path)) `
        "Screenshot path already exists: $path"
}

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

$smokeSource = Join-Path $PSScriptRoot 'P8WebViewSmoke.cs'
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
        $rawResult = [MacroDesk.Tests.P8WebViewSmoke]::Run(
            $repoRoot,
            $cacheDir,
            $presetScreenshot,
            $guidedScreenshot,
            $errorScreenshot)
    } catch {
        throw $_.Exception.ToString()
    }

    $result = $rawResult | ConvertFrom-Json
    $guided = $result.guided
    $errors = $result.errors
    $builds = $result.builds
    $logs = $result.logRecords | ConvertFrom-Json
    $lecture = $result.lectureRender | ConvertFrom-Json
    $themeLight = $result.themeLight | ConvertFrom-Json
    $themeDark = $result.themeDark | ConvertFrom-Json
    $themeRestored = $result.themeRestored | ConvertFrom-Json

    Assert-True (
        $themeLight.theme -eq 'light' -and
        [string]::IsNullOrEmpty([string]$themeLight.stored) -and
        $themeLight.background -eq 'rgb(244, 246, 248)' -and
        $themeLight.visibleIcons -eq 1 -and
        -not $themeLight.guided) `
        'The default light theme is not applied as designed.'
    Assert-True (
        $themeDark.theme -eq 'dark' -and
        $themeDark.stored -eq 'dark' -and
        $themeDark.background -eq 'rgb(20, 23, 27)' -and
        $themeDark.visibleIcons -eq 1 -and
        -not $themeDark.guided -and
        $themeDark.label -ne $themeLight.label -and
        -not [string]::IsNullOrEmpty([string]$themeDark.announced)) `
        'The dark theme toggle or persistence is incomplete.'
    Assert-True (
        $themeRestored.theme -eq 'light' -and
        $themeRestored.stored -eq 'light' -and
        $themeRestored.background -eq 'rgb(244, 246, 248)') `
        'The theme toggle did not restore and persist light mode.'

    $step1Unattached = Get-JsonProperty `
        $guided 'step1Unattached'
    $step1Attached = Get-JsonProperty `
        $guided 'step1Attached'
    $step2Empty = Get-JsonProperty $guided 'step2Empty'
    $step2EmptyNoPresets = Get-JsonProperty `
        $guided 'step2EmptyNoPresets'
    $step2Text = Get-JsonProperty $guided 'step2Text'
    $step2Created = Get-JsonProperty $guided 'step2Created'
    $step3Unselected = Get-JsonProperty `
        $guided 'step3Unselected'
    $step3Selected = Get-JsonProperty `
        $guided 'step3Selected'
    $step3ChangedPending = Get-JsonProperty `
        $guided 'step3ChangedPending'
    $step3ChangedComplete = Get-JsonProperty `
        $guided 'step3ChangedComplete'
    $step3NoChange = Get-JsonProperty `
        $guided 'step3NoChange'
    $step4Confirmation = Get-JsonProperty `
        $guided 'step4Confirmation'
    $step4Success = Get-JsonProperty $guided 'step4Success'

    Assert-Guided $step1Unattached `
        'book-drop-zone' 'Step 1 unattached'
    Assert-Guided $step1Attached `
        'step1-next' 'Step 1 attached'
    Assert-Guided $step2Empty `
        'preset-section' 'Step 2 empty'
    Assert-Guided $step2EmptyNoPresets `
        'request-textarea' 'Step 2 empty without presets'
    Assert-Guided $step2Text `
        'create-request' 'Step 2 with request'
    Assert-Guided $step2Created `
        'step2-next' 'Step 2 created'
    Assert-Guided $step3Unselected `
        'ModuleA' 'Step 3 unselected'
    Assert-Guided $step3Selected `
        'paste-response' 'Step 3 selected'
    Assert-Guided $step3ChangedPending `
        'ModuleB' 'Step 3 changed with pending'
    Assert-True (
        $step3ChangedPending.step4Ready -and
        -not $step3ChangedPending.step4Guided) `
        'Step 4 must be ready but not glowing while pending remains.'
    Assert-Guided $step3ChangedComplete `
        'step3-next' 'Step 3 changed and complete'
    Assert-True (
        $step3ChangedComplete.step4Ready -and
        -not $step3ChangedComplete.step4Guided -and
        $step3ChangedComplete.doneBar) `
        'The completion bar must guide to step 4 after pending reaches zero.'
    Assert-True (
        $step3NoChange.guided -eq 0 -and
        -not $step3NoChange.step4Ready -and
        -not $step3NoChange.doneBar) `
        'A no-change completion must not offer or guide build navigation.'
    Assert-Guided $step4Confirmation `
        'build-book' 'Step 4 confirmation'
    Assert-True ($step4Confirmation.branch -eq 'L4-1') `
        'Step 4 confirmation lecture mismatch.'
    Assert-Guided $step4Success `
        'reveal-build-output' 'Step 4 success'
    Assert-True ($step4Success.branch -eq 'L4-2') `
        'Step 4 success lecture mismatch.'

    foreach ($code in @(
        'E-BUILD-01',
        'E-BUILD-02',
        'E-BUILD-03')) {
        $metric = Get-JsonProperty $builds $code
        Assert-Guided $metric `
            'retry-build' "Build error $code"
        Assert-True (
            $metric.buildView -eq 'error' -and
            $metric.branch -eq 'L-E*' -and
            $metric.errorCode -eq $code) `
            "Build error presentation mismatch: $code"
        Assert-True (-not $metric.collapsed) `
            "Build error did not open the lecture: $code"
        Assert-True (
            [string]$metric.body -notmatch 'RAW' -and
            [string]::IsNullOrEmpty([string]$metric.toast)) `
            "Build error exposed raw detail or used a toast: $code"
    }

    foreach ($code in @(
        'E-ATTACH-02',
        'E-ATTACH-03',
        'E-GEN-01',
        'E-GEN-02',
        'E-PASTE-01',
        'E-SYS-01',
        'E-SYS-02')) {
        $metric = Get-JsonProperty $errors $code
        Assert-True (
            $metric.branch -eq 'L-E*' -and
            $metric.errorCode -eq $code) `
            "Error lecture branch mismatch: $code"
        Assert-True (-not $metric.collapsed) `
            "Error did not open the lecture: $code"
        Assert-True (
            -not [string]::IsNullOrEmpty([string]$metric.title) -and
            -not [string]::IsNullOrEmpty([string]$metric.body) -and
            [string]$metric.body -notmatch 'RAW') `
            "Error guidance is empty or exposed raw detail: $code"
        Assert-True (-not $metric.horizontal) `
            "Error state has horizontal scroll: $code"

        if ($code -eq 'E-ATTACH-03') {
            Assert-True (
                $metric.cardRole -eq 'alert' -and
                -not [string]::IsNullOrEmpty([string]$metric.card) -and
                [string]::IsNullOrEmpty([string]$metric.toast)) `
                'E-ATTACH-03 must use the main error card.'
        } else {
            Assert-True (
                $metric.toastRole -eq 'alert' -and
                -not [string]::IsNullOrEmpty([string]$metric.toast)) `
                "Error must use an alert toast: $code"
        }
    }

    $pasteError = Get-JsonProperty $errors 'E-PASTE-01'
    Assert-True ($pasteError.activeAction -eq 'paste-response') `
        'E-PASTE-01 did not focus the paste action.'
    Assert-True $pasteError.focusRule `
        'The WebView does not contain a focus-visible outline rule.'

    $errorLogs = @($logs | Where-Object {
        $_.level -eq 'ERROR'
    })
    Assert-True ($errorLogs.Count -ge 6) `
        'Client error paths were not linked to writeLog.'
    foreach ($entry in $errorLogs) {
        Assert-True (
            [string]$entry.message -notmatch
                'Option Explicit|Public Sub') `
            'An error log contains VBA code text.'
    }

    Assert-True (
        $lecture.branches -eq 16 -and
        $lecture.errors -eq 10 -and
        $lecture.branchLines -and
        $lecture.errorLines) `
        'Lecture branch/error table is incomplete.'

    foreach ($path in @(
        $presetScreenshot,
        $guidedScreenshot,
        $errorScreenshot)) {
        Assert-True ([IO.File]::Exists($path)) `
            "P8 screenshot was not created: $path"
    }

    Write-Host 'test-p8-webview: PASS'
    Write-Host (
        'lecture=16 branches/10 errors, glow=exclusive, ' +
        'focus/font/logging=PASS')
    Write-Host (
        'errors=toast/card/build-screen, screenshots=created')
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
            Start-Sleep -Milliseconds 50
        }
    }
    Assert-True (-not [IO.Directory]::Exists($cacheDir)) `
        "P8 WebView cache was not removed: $cacheDir"

    if (-not $preserveScreenshots) {
        foreach ($path in @(
            $presetScreenshot,
            $guidedScreenshot,
            $errorScreenshot)) {
            if ([IO.File]::Exists($path)) {
                [IO.File]::Delete($path)
            }
        }
    }
}
