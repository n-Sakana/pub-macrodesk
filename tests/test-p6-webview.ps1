param(
    [string]$BookPath,
    [string]$ProductRoot,
    [string]$WaitingScreenshotPath,
    [string]$DiffScreenshotPath,
    [string]$BuildScreenshotPath,
    [string]$FailureScreenshotPath,
    [string]$SuccessScreenshotPath,
    [string]$ReportScreenshotPath
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

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
}

$sourceRepoRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrEmpty($ProductRoot)) {
    $ProductRoot = $sourceRepoRoot
}
$repoRoot = (Resolve-Path -LiteralPath $ProductRoot).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$libDir = Join-Path $repoRoot 'lib'
$buildLabel = [IO.File]::ReadAllText(
    (Join-Path $repoRoot 'assets\messages\build-file-label.txt'),
    [Text.Encoding]::UTF8).Trim()
$cacheDir = Join-Path $testdataRoot (
    'p6-webview-cache-' + [Guid]::NewGuid().ToString('N'))
$preserveScreenshots =
    -not [string]::IsNullOrEmpty($WaitingScreenshotPath) -and
    -not [string]::IsNullOrEmpty($DiffScreenshotPath) -and
    -not [string]::IsNullOrEmpty($BuildScreenshotPath) -and
    -not [string]::IsNullOrEmpty($FailureScreenshotPath) -and
    -not [string]::IsNullOrEmpty($SuccessScreenshotPath) -and
    -not [string]::IsNullOrEmpty($ReportScreenshotPath)

if ([string]::IsNullOrEmpty($WaitingScreenshotPath)) {
    $WaitingScreenshotPath = Join-Path $testdataRoot (
        'p6-waiting-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($DiffScreenshotPath)) {
    $DiffScreenshotPath = Join-Path $testdataRoot (
        'p6-diff-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($BuildScreenshotPath)) {
    $BuildScreenshotPath = Join-Path $testdataRoot (
        'p7-build-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($FailureScreenshotPath)) {
    $FailureScreenshotPath = Join-Path $testdataRoot (
        'p7-failure-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($SuccessScreenshotPath)) {
    $SuccessScreenshotPath = Join-Path $testdataRoot (
        'p7-success-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($ReportScreenshotPath)) {
    $ReportScreenshotPath = Join-Path $testdataRoot (
        'p6-report-' + [Guid]::NewGuid().ToString('N') + '.png')
}

$waitingScreenshot = [IO.Path]::GetFullPath(
    $WaitingScreenshotPath)
$diffScreenshot = [IO.Path]::GetFullPath(
    $DiffScreenshotPath)
$buildScreenshot = [IO.Path]::GetFullPath(
    $BuildScreenshotPath)
$failureScreenshot = [IO.Path]::GetFullPath(
    $FailureScreenshotPath)
$successScreenshot = [IO.Path]::GetFullPath(
    $SuccessScreenshotPath)
$reportScreenshot = [IO.Path]::GetFullPath(
    $ReportScreenshotPath)
Assert-InsideDirectory $cacheDir $testdataRoot
Assert-InsideDirectory $waitingScreenshot $testdataRoot
Assert-InsideDirectory $diffScreenshot $testdataRoot
Assert-InsideDirectory $buildScreenshot $testdataRoot
Assert-InsideDirectory $failureScreenshot $testdataRoot
Assert-InsideDirectory $successScreenshot $testdataRoot
Assert-InsideDirectory $reportScreenshot $testdataRoot
Assert-True (-not [IO.File]::Exists($waitingScreenshot)) `
    "Waiting screenshot already exists: $waitingScreenshot"
Assert-True (-not [IO.File]::Exists($diffScreenshot)) `
    "Diff screenshot already exists: $diffScreenshot"
Assert-True (-not [IO.File]::Exists($buildScreenshot)) `
    "Build screenshot already exists: $buildScreenshot"
Assert-True (-not [IO.File]::Exists($failureScreenshot)) `
    "Failure screenshot already exists: $failureScreenshot"
Assert-True (-not [IO.File]::Exists($successScreenshot)) `
    "Success screenshot already exists: $successScreenshot"
Assert-True (-not [IO.File]::Exists($reportScreenshot)) `
    "Report screenshot already exists: $reportScreenshot"

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
$smokeSource = Join-Path $PSScriptRoot 'P6WebViewSmoke.cs'
$combined = (@($sourceFiles.FullName) + @($smokeSource) |
    ForEach-Object {
        [IO.File]::ReadAllText($_, [Text.Encoding]::UTF8)
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
    'System.IO.Compression'
    'System.IO.Compression.FileSystem'
    $corePath
    $wpfPath
)

Add-Type -TypeDefinition $source `
    -ReferencedAssemblies $references `
    -Language CSharp

try {
    try {
        $rawResult = [MacroDesk.Tests.P6WebViewSmoke]::Run(
            $repoRoot,
            $resolvedBookPath,
            $cacheDir,
            $waitingScreenshot,
            $diffScreenshot,
            $buildScreenshot,
            $failureScreenshot,
            $successScreenshot,
            $reportScreenshot)
    } catch {
        throw $_.Exception.ToString()
    }

    $result = $rawResult | ConvertFrom-Json
    $initial = $result.initial | ConvertFrom-Json
    $waiting = $result.waiting | ConvertFrom-Json
    $normal = $result.normal | ConvertFrom-Json
    $undone = $result.undone | ConvertFrom-Json
    $identical = $result.identical | ConvertFrom-Json
    $keyboard = $result.keyboard | ConvertFrom-Json
    $preserved = $result.preserved | ConvertFrom-Json
    $excludedClick = $result.excludedClick | ConvertFrom-Json
    $excludedContext = $result.excludedContext | ConvertFrom-Json
    $empty = $result.empty | ConvertFrom-Json
    $wrongModule = $result.wrongModule | ConvertFrom-Json
    $newIntake = $result.newIntake | ConvertFrom-Json
    $newModule = $result.newModule | ConvertFrom-Json
    $largeFull = $result.largeFull | ConvertFrom-Json
    $largeContext = $result.largeContext | ConvertFrom-Json
    $buildConfirmation =
        $result.buildConfirmation | ConvertFrom-Json
    $buildFailure = $result.buildFailure | ConvertFrom-Json
    $buildRetry = $result.buildRetry | ConvertFrom-Json
    $buildProgress = $result.buildProgress | ConvertFrom-Json
    $buildSuccess = $result.buildSuccess | ConvertFrom-Json
    $diffFailure = $result.diffFailure | ConvertFrom-Json
    $diffReport = $result.diffReport | ConvertFrom-Json
    $selfLoop = $result.selfLoop | ConvertFrom-Json

    Assert-True ($initial.modules -eq 6) `
        'P6 did not attach all six modules.'
    Assert-True ($null -eq $initial.selected) `
        'Step 3 must start without a selected module.'
    Assert-True ($initial.glow -eq 1) `
        'The first pending module must glow when none is selected.'
    Assert-True (-not $initial.step4) `
        'Step 4 must not glow before a changed module exists.'
    Assert-True ($initial.branch -eq 'L3-1') `
        'Unselected Step 3 lecture branch mismatch.'
    Assert-True (-not $initial.horizontal) `
        'Unselected Step 3 has document-level horizontal scroll.'

    Assert-True ($waiting.panes -eq 2) `
        'Pending module must show two code panes.'
    Assert-True ($waiting.sourceRows -eq 4) `
        'TimerUtils current-code row count mismatch.'
    Assert-True ($waiting.tokens -gt 0) `
        'VBA syntax highlighting is missing.'
    Assert-True ($waiting.paste -and $waiting.primary) `
        'The primary paste target is missing.'
    Assert-True ($waiting.branch -eq 'L3-2') `
        'Pending-module lecture branch mismatch.'
    Assert-True ($waiting.moduleGlow -eq 0) `
        'The list must not compete with the selected paste target.'

    Assert-True ($normal.status -eq 'changed') `
        'Changed paste status mismatch.'
    Assert-True ($normal.count -eq 1) `
        'Owner-approved changed-line count must be one.'
    Assert-True ($normal.pasted -ceq $result.changedCode) `
        'Normalized pasted code mismatch.'
    Assert-True (-not $normal.fence -and -not $normal.attribute) `
        'Fence or leading Attribute text survived normalization.'
    Assert-True ($normal.nonEqual -eq 1) `
        'One-line edit must render one non-equal diff row.'
    Assert-True ($normal.result -match '1') `
        'Changed-line result is missing from the UI.'
    Assert-True ($normal.badge -match '1') `
        'Changed-line count is missing from the module badge.'
    Assert-True ($normal.branch -eq 'L3-3') `
        'Changed diff lecture branch mismatch.'
    Assert-True ($normal.logs.Count -eq 2) `
        'Attach and paste logs were not emitted exactly once.'
    Assert-True (
        $normal.logs[0] -match
        '^attach: .+ \(6 modules\)$') `
        'Attach log path or module count mismatch.'
    Assert-True ($normal.logs[1] -eq 'paste: TimerUtils (4 lines)') `
        'Paste log must contain only module name and line count.'
    Assert-True (
        ($normal.logs -join "`n") -notmatch
        'Option Explicit|Attribute VB_|Debug\.Print') `
        'Attach or paste log leaked code content.'
    Assert-True (-not $normal.horizontal) `
        'Diff screen has document-level horizontal scroll.'

    Assert-True ($undone.status -eq 'pending') `
        'Undo did not restore pending status.'
    Assert-True ($null -eq $undone.pasted) `
        'Undo did not clear pasted code.'
    Assert-True ($undone.paste) `
        'Undo did not restore the paste target.'

    Assert-True ($identical.status -eq 'unchanged') `
        'Identical paste must enter unchanged status.'
    Assert-True ($identical.count -eq 0) `
        'Identical paste changed-line count must be zero.'
    Assert-True ($identical.nonEqual -eq 0) `
        'Identical paste rendered non-equal rows.'
    Assert-True ($identical.badge -eq ([char]0x540C)) `
        'Unchanged badge text mismatch.'
    Assert-True ($identical.branch -eq 'L3-4') `
        'Unchanged diff lecture branch mismatch.'

    Assert-True ($keyboard.status -eq 'changed') `
        'Paste-event route did not replace the accepted code.'
    Assert-True ($keyboard.count -eq 1) `
        'Paste-event changed-line count mismatch.'
    Assert-True ($keyboard.prevented) `
        'Paste-event default action was not prevented.'
    Assert-True ($keyboard.nextGlow -eq 1) `
        'Next pending module did not glow after confirmation.'
    Assert-True ($keyboard.step4) `
        'Step 4 did not light after a changed module was confirmed.'

    Assert-True ($preserved.selected -eq 'TimerUtils') `
        'Step 2/3 round trip lost module selection.'
    Assert-True ($preserved.status -eq 'changed') `
        'Step 2/3 round trip lost module status.'
    Assert-True ($preserved.pasted -ceq $result.changedCode) `
        'Step 2/3 round trip lost pasted code.'

    Assert-True ($excludedClick.status -eq 'excluded') `
        'Badge click did not set excluded status.'
    Assert-True ($excludedClick.strike) `
        'Excluded module name is not struck through.'
    Assert-True (
        -not [string]::IsNullOrEmpty($excludedClick.release)) `
        'Excluded badge has no accessible release label.'
    Assert-True ($excludedContext -eq 'excluded') `
        'Context-menu toggle did not set excluded status.'

    Assert-True ($empty.status -eq 'pending') `
        'Empty paste changed module status.'
    Assert-True ($null -eq $empty.pasted) `
        'Empty paste stored code.'
    Assert-True (-not [string]::IsNullOrEmpty($empty.toast)) `
        'Empty paste toast is missing.'
    Assert-True ($empty.branch -eq 'L-E*') `
        'Empty paste error lecture branch mismatch.'
    Assert-True (-not $empty.collapsed) `
        'Empty paste error did not keep the lecture open.'

    Assert-True ($wrongModule.count -eq $wrongModule.nonEqual) `
        'Wrong-module badge count and diff rows disagree.'
    Assert-True ($wrongModule.nonEqual -ge 2) `
        'Wrong-module paste did not produce a conspicuous diff.'
    Assert-True (
        ([double]$wrongModule.nonEqual / [double]$wrongModule.rows) `
        -ge 0.4) `
        'Wrong-module diff is not visually dominant.'

    Assert-True ($newIntake.form -and $newIntake.input) `
        'New standard module intake form is missing.'
    Assert-True (
        $newIntake.guided -eq 1 -and
        $newIntake.moduleGlow -eq 0 -and
        -not $newIntake.step4Guided) `
        'New module intake must have exactly one guided action.'
    Assert-True (
        $newModule.count -eq 7 -and
        $newModule.selected -eq 'CommonHelpers' -and
        $newModule.status -eq 'changed' -and
        $newModule.isNew -and
        $newModule.type -eq 'standard') `
        'New standard module state mismatch.'
    Assert-True ($newModule.code -ceq $result.additionCode) `
        'New module pasted code mismatch.'
    Assert-True ($newModule.badge -eq ([char]0x65B0)) `
        'New module badge mismatch.'
    Assert-True (
        $newModule.diff -gt 0 -and $newModule.step4) `
        'New module diff or Step 4 readiness is missing.'

    Assert-True ($largeFull.rows -eq 5001) `
        'Large-module full view row count mismatch.'
    Assert-True ($largeFull.gaps -eq 0) `
        'Large-module full view must not contain gaps.'
    Assert-True ($largeFull.pressed -eq 'false') `
        'Changes-only toggle must default off.'
    Assert-True ($largeFull.clientHeight -gt 0) `
        'Large diff scroller has no visible height.'
    Assert-True (
        $largeFull.scrollHeight -gt $largeFull.clientHeight) `
        'Large diff content does not overflow its scroller.'
    Assert-True ($largeFull.canScroll) `
        'Large diff cannot scroll vertically.'
    Assert-True ($largeFull.hostDisplay -eq 'flex') `
        'Diff table host does not provide a flex context.'
    Assert-True ($largeContext.rows -eq 21) `
        'Changes-only view must retain plus/minus ten lines.'
    Assert-True ($largeContext.gaps -eq 2) `
        'Changes-only view must show two omission markers.'
    Assert-True ($largeContext.pressed -eq 'true') `
        'Changes-only toggle state mismatch.'
    Assert-True (-not $largeContext.horizontal) `
        'Large diff caused document-level horizontal scroll.'

    Assert-True ($buildConfirmation.view -eq 'confirmation') `
        'Step 4 confirmation view is missing.'
    Assert-True (
        $buildConfirmation.targets -eq 4 -and
        $buildConfirmation.changed -eq 4) `
        'Step 4 write-back target count mismatch.'
    Assert-True (
        $buildConfirmation.timestamp -match
        '^\d{8}_\d{6}$') `
        'Step 4 output timestamp format mismatch.'
    $expectedConfirmationName = (
        'test_large_' +
        $buildLabel +
        '_' +
        $buildConfirmation.timestamp +
        '.xlsm')
    Assert-True (
        $buildConfirmation.output -ceq
        $expectedConfirmationName) `
        'Step 4 output file name mismatch.'
    Assert-True (
        $buildConfirmation.build -and
        $buildConfirmation.branch -eq 'L4-1') `
        'Step 4 confirmation action or lecture branch mismatch.'
    Assert-True (-not $buildConfirmation.horizontal) `
        'Step 4 confirmation has document-level horizontal scroll.'

    Assert-True (
        $buildFailure.view -eq 'error' -and
        $buildFailure.code -eq 'E-BUILD-02') `
        'Build verification failure view mismatch.'
    Assert-True (
        $buildFailure.rows -eq 1 -and
        -not [string]::IsNullOrEmpty($buildFailure.result) -and
        $buildFailure.result -ne 'verify_failed') `
        'Build failure result table mismatch.'
    Assert-True (
        -not [string]::IsNullOrEmpty($buildFailure.discarded) -and
        $buildFailure.branch -eq 'L-E*') `
        'Build failure recovery guidance mismatch.'

    Assert-True ($buildRetry.view -eq 'confirmation') `
        'Build retry did not return to confirmation.'
    Assert-True ($buildRetry.timestamp -match '^\d{8}_\d{6}$') `
        'Build retry did not issue a valid timestamp.'
    Assert-True (
        $buildProgress.view -eq 'progress' -and
        $buildProgress.spinner) `
        'Build progress feedback is missing.'
    Assert-True ($buildProgress.disabled -eq 4) `
        'Progress navigation remained active during build.'

    Assert-True ($buildSuccess.view -eq 'success') `
        'Build success view is missing.'
    Assert-True ($buildSuccess.output -eq $result.buildOutputPath) `
        'Success path does not match the host response.'
    Assert-True (
        [IO.Path]::GetFileName($buildSuccess.output) -ceq
        $buildSuccess.expected) `
        'Displayed confirmation name and actual output name differ.'
    Assert-True (
        $buildSuccess.written -eq 4 -and
        $buildSuccess.results -eq 4) `
        'Written badges or build results are incomplete.'
    Assert-True (
        $buildSuccess.diff -eq $result.diffOutputPath -and
        [string]::IsNullOrEmpty($buildSuccess.diffError)) `
        'Diff report success data is incomplete.'
    Assert-True (
        $buildSuccess.reveal -and
        $buildSuccess.excel -match 'Excel' -and
        $buildSuccess.branch -eq 'L4-2') `
        'Build success guidance or reveal action mismatch.'
    Assert-True (-not $buildSuccess.horizontal) `
        'Build success has document-level horizontal scroll.'
    Assert-True ($result.buildReveal -eq $result.buildOutputPath) `
        'Reveal action did not receive the output path.'
    Assert-True (
        $diffFailure.view -eq 'success' -and
        $diffFailure.output -eq $result.buildOutputPath -and
        $diffFailure.reveal) `
        'Diff report failure incorrectly cancelled build success.'
    Assert-True (
        $diffFailure.toast -match 'HTML' -and
        $diffFailure.toast.Length -gt 20) `
        ("Diff report failure toast does not preserve build success: " +
        $diffFailure.toast)
    Assert-True ($diffFailure.announce -match 'HTML') `
        'Diff report failure was not announced.'

    Assert-True (
        $selfLoop.targets -eq 4 -and
        $selfLoop.unchanged -eq 4 -and
        $selfLoop.exact -eq 4) `
        'Reattached write-back targets are not exact matches.'
    Assert-True (
        $selfLoop.changed -eq 0 -and
        -not $selfLoop.step4) `
        'Self-verification loop still reports a changed module.'
    Assert-True (
        $diffReport.modules -eq 4 -and
        $diffReport.tables -eq 4 -and
        $diffReport.scrollers -eq 4) `
        'Generated diff report does not contain all changed modules.'
    Assert-True (
        $diffReport.newModule -and
        $diffReport.changedRows -gt 0) `
        'Generated diff report omitted a new module or changed rows.'
    Assert-True (
        $diffReport.external -eq 0 -and
        $diffReport.scripts -eq 0 -and
        $diffReport.styles -eq 1) `
        'Generated diff report is not self-contained.'
    Assert-True (
        $diffReport.vertical -and
        -not $diffReport.horizontal) `
        'Generated diff report scrolling is incorrect.'
    Assert-True (-not $diffReport.pathLeak) `
        'Generated diff report contains an absolute test path.'
    Assert-True (-not [IO.File]::Exists($result.buildOutputPath)) `
        'P7 smoke output was not removed.'
    Assert-True (-not [IO.File]::Exists($result.diffOutputPath)) `
        'Diff report smoke output was not removed.'

    Assert-True ([IO.File]::Exists($waitingScreenshot)) `
        'Waiting screenshot was not created.'
    Assert-True ([IO.File]::Exists($diffScreenshot)) `
        'Diff screenshot was not created.'
    Assert-True ([IO.File]::Exists($buildScreenshot)) `
        'Build confirmation screenshot was not created.'
    Assert-True ([IO.File]::Exists($failureScreenshot)) `
        'Build failure screenshot was not created.'
    Assert-True ([IO.File]::Exists($successScreenshot)) `
        'Build success screenshot was not created.'
    Assert-True ([IO.File]::Exists($reportScreenshot)) `
        'Diff report screenshot was not created.'

    Write-Host 'test-p6-webview: PASS'
    Write-Host (
        'attach=6, paste=clipboard+event, normalize=4 rules, ' +
        'diff=count-A, undo/unchanged/excluded/state=PASS')
    Write-Host (
        'wrong-module=conspicuous, 5001-lines=context+/-10, ' +
        'build/diff-report/self-loop=PASS, screenshots=created')
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
        "P6 WebView cache was not removed: $cacheDir"

    if (-not $preserveScreenshots) {
        foreach ($path in @(
            $waitingScreenshot,
            $diffScreenshot,
            $buildScreenshot,
            $failureScreenshot,
            $successScreenshot,
            $reportScreenshot)) {
            if ([IO.File]::Exists($path)) {
                [IO.File]::Delete($path)
            }
        }
    }
}
