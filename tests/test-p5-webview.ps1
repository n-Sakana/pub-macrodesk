param(
    [string]$BookPath,
    [string]$ProductRoot,
    [string]$StepOneScreenshotPath,
    [string]$StepTwoScreenshotPath
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
        [string]::Equals(
            $fullPath,
            $fullDirectory,
            [StringComparison]::OrdinalIgnoreCase) -or
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
$bookDirectory = [IO.Path]::GetDirectoryName($resolvedBookPath)
Assert-InsideDirectory $bookDirectory $testdataRoot
$libDir = Join-Path $repoRoot 'lib'
$requestLabel = [IO.File]::ReadAllText(
    (Join-Path $repoRoot 'assets\messages\code-file-label.txt'),
    [Text.Encoding]::UTF8).Trim()
$cacheDir = Join-Path $testdataRoot (
    'p5-webview-cache-' + [Guid]::NewGuid().ToString('N'))
$preserveScreenshots =
    -not [string]::IsNullOrEmpty($StepOneScreenshotPath) -and
    -not [string]::IsNullOrEmpty($StepTwoScreenshotPath)

if ([string]::IsNullOrEmpty($StepOneScreenshotPath)) {
    $StepOneScreenshotPath = Join-Path $testdataRoot (
        'p5-step1-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($StepTwoScreenshotPath)) {
    $StepTwoScreenshotPath = Join-Path $testdataRoot (
        'p5-step2-' + [Guid]::NewGuid().ToString('N') + '.png')
}

$stepOneScreenshot = [IO.Path]::GetFullPath(
    $StepOneScreenshotPath)
$stepTwoScreenshot = [IO.Path]::GetFullPath(
    $StepTwoScreenshotPath)
Assert-InsideDirectory $cacheDir $testdataRoot
Assert-InsideDirectory $stepOneScreenshot $testdataRoot
Assert-InsideDirectory $stepTwoScreenshot $testdataRoot
Assert-True (-not [IO.File]::Exists($stepOneScreenshot)) `
    "Step 1 screenshot already exists: $stepOneScreenshot"
Assert-True (-not [IO.File]::Exists($stepTwoScreenshot)) `
    "Step 2 screenshot already exists: $stepTwoScreenshot"

$requestPattern = (
    [IO.Path]::GetFileNameWithoutExtension($resolvedBookPath) +
    '_' + $requestLabel + '_*.txt')
$beforeRequestFiles = @{}
foreach ($file in Get-ChildItem -LiteralPath $bookDirectory `
    -Filter $requestPattern -File) {
    $beforeRequestFiles[$file.FullName] = $true
}

$shell = New-Object -ComObject Shell.Application
$beforeWindows = @($shell.Windows())
$beforeHandles = @{}
foreach ($shellWindow in $beforeWindows) {
    $beforeHandles[[string]$shellWindow.HWND] = $true
}

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
$smokeSource = Join-Path $PSScriptRoot 'P5WebViewSmoke.cs'
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

$requestPath = ''
try {
    try {
        $rawResult = [MacroDesk.Tests.P5WebViewSmoke]::Run(
            $repoRoot,
            $resolvedBookPath,
            $cacheDir,
            $stepOneScreenshot,
            $stepTwoScreenshot)
    } catch {
        throw $_.Exception.ToString()
    }

    $result = $rawResult | ConvertFrom-Json
    $initial = $result.initial | ConvertFrom-Json
    $attached = $result.attached | ConvertFrom-Json
    $errors = $result.errors | ConvertFrom-Json
    $cancelled = $result.cancelled | ConvertFrom-Json
    $reset = $result.reset | ConvertFrom-Json
    $empty = $result.empty | ConvertFrom-Json
    $preset = $result.preset | ConvertFrom-Json
    $success = $result.success | ConvertFrom-Json
    $preserved = $result.preserved | ConvertFrom-Json
    $parsedLogs = $result.logs | ConvertFrom-Json
    $logs = @($parsedLogs)
    $requestPath = $success.path

    Assert-True ($initial.step -eq 1) `
        'P5 initial screen is not step 1.'
    Assert-True ($initial.drop -eq $true) `
        'Step 1 drop zone is missing.'
    Assert-True ($initial.pick -eq $true) `
        'Step 1 file picker button is missing.'
    Assert-True ($initial.presets -eq 1) `
        'Sample preset was not returned by getAppInfo.'
    Assert-True (
        [double]$initial.documentWidth -le
        [double]$initial.viewportWidth) `
        'Initial screen has horizontal document scroll.'

    Assert-True ($attached.book.name -eq 'test_large.xlsm') `
        'Attached book name mismatch.'
    Assert-True ($attached.book.totalLines -eq 19) `
        'Attached book total line count mismatch.'
    Assert-True ($attached.modules -eq 6) `
        'Attached module count mismatch.'
    Assert-True ($attached.pending -eq 6) `
        'Attached modules must all start pending.'
    Assert-True ($attached.bookCard -eq $true) `
        'Attached book information card is missing.'
    Assert-True (
        [double]$attached.documentWidth -le
        [double]$attached.viewportWidth) `
        'Attached screen has horizontal document scroll.'

    foreach ($code in @(
        'E-ATTACH-01',
        'E-ATTACH-02',
        'E-ATTACH-03',
        'E-ATTACH-04',
        'E-ATTACH-05')) {
        $entry = $errors.$code
        Assert-True ($entry.state -eq $code) `
            "Attach error state mismatch: $code"
        Assert-True ($entry.book -eq 'test_large.xlsm') `
            "Attach error destroyed the current book: $code"
        Assert-True ($entry.modules -eq 6) `
            "Attach error destroyed modules: $code"
        if ($code -eq 'E-ATTACH-03') {
            Assert-True ($entry.card -eq $true) `
                'E-ATTACH-03 card is missing.'
        } else {
            Assert-True (
                -not [string]::IsNullOrEmpty($entry.toast)) `
                "Attach error toast is missing: $code"
        }
    }

    Assert-True ($cancelled.dialogOpen -eq $false) `
        'Imported-content replacement dialog did not close.'
    Assert-True ($cancelled.status -eq 'changed') `
        'Cancelled replacement changed module state.'
    Assert-True ($reset.step -eq 1) `
        'Confirmed replacement did not return to step 1.'
    Assert-True ($reset.pending -eq 6) `
        'Confirmed replacement did not reset all modules.'
    Assert-True ($reset.lectureCollapsed -eq $false) `
        'Confirmed replacement did not reopen the lecture.'
    Assert-True ($reset.requestText -eq '') `
        'Confirmed replacement did not reset request text.'

    Assert-True ([string]::IsNullOrEmpty($empty.path)) `
        'Whitespace-only request created a file.'
    $emptyRequestMarker = -join @(
        [char]0x4F9D,
        [char]0x983C,
        [char]0x304C,
        [char]0x7A7A,
        [char]0x3067,
        [char]0x3059)
    Assert-True ($empty.toast.Contains($emptyRequestMarker)) `
        "Whitespace-only request toast is missing. Actual=$($empty.toast)"
    Assert-True ($empty.invalid -eq 'true') `
        'Whitespace-only request did not mark the textarea invalid.'

    $presetFiles = @(Get-ChildItem -LiteralPath (
        Join-Path $repoRoot 'presets') -Filter '*.md' -File)
    Assert-True ($presetFiles.Count -eq 1) `
        'Expected exactly one sample preset.'
    $presetPath = $presetFiles[0].FullName
    $presetContent = [IO.File]::ReadAllText(
        $presetPath,
        [Text.Encoding]::UTF8)
    $expectedRequestText =
        'existing request' + "`r`n`r`n" + $presetContent
    Assert-True ($preset.requestText -ceq $expectedRequestText) `
        'Preset append does not match the append policy.'
    Assert-True ($preset.presetCount -eq 1) `
        'Preset button count mismatch.'
    Assert-True ($preset.noticeOpen -eq $false) `
        'Template notice must start collapsed.'
    Assert-True (
        -not [string]::IsNullOrEmpty(
            [string]$preset.templateSummary)) `
        'Template notice summary is missing.'
    Assert-True (
        $preset.templateText.Contains(
            'templates\request-template.txt') -and
        $preset.templateText.Contains('{{REQUEST_TEXT}}') -and
        -not $preset.templateText.Contains(
            '{{MODULE_SOURCE_BLOCKS}}')) `
        'Template notice does not explain its path and required insertions.'
    Assert-True ($preset.branch -eq 'L2-2') `
        'Step 2 lecture branch mismatch before creation.'
    Assert-True ($preset.horizontal -eq $false) `
        'Step 2 screen has horizontal document scroll.'
    $presetFile = Get-ChildItem (Join-Path $repoRoot 'presets') `
        -Filter '*.md' | Select-Object -First 1
    $presetBody = [IO.File]::ReadAllText(
        $presetFile.FullName,
        [Text.Encoding]::UTF8).Trim()
    $presetFirstLine = ($presetBody -split "`r?`n")[0].Trim()
    Assert-True (
        $presetFirstLine.Length -gt 0 -and
        ([string]$preset.requestText).Contains($presetFirstLine) -and
        ([string]$preset.requestText).Contains('Win32 API')) `
        'Preset did not inject the migration request.'
    Assert-True (
        -not ([string]$preset.requestText).Contains('64 bit') -and
        -not ([string]$preset.requestText).Contains('64bit') -and
        -not ([string]$preset.requestText).Contains('PtrSafe') -and
        -not ([string]$preset.requestText).Contains('Sleep')) `
        'Preset still injects legacy wording.'

    Assert-InsideDirectory $requestPath $bookDirectory
    Assert-True ([IO.File]::Exists($requestPath)) `
        'Request file was not created.'
    $requestNamePattern =
        '^test_large_' +
        [regex]::Escape($requestLabel) +
        '_\d{8}_\d{6}\.txt$'
    Assert-True (
        [IO.Path]::GetFileName($requestPath) -match
        $requestNamePattern) `
        'Request file name mismatch.'
    $createdPrefix = ([char]0x2713) + [char]0x0020
    Assert-True ($success.heading -eq (
        $createdPrefix + [IO.Path]::GetFileName($requestPath))) `
        'Created request status text mismatch.'
    Assert-True ($success.next -eq $true) `
        'Step 2 next button is missing after creation.'
    Assert-True ($success.copyAgain -eq $true) `
        'Re-copy button is missing after creation.'
    Assert-True ($success.branch -eq 'L2-3') `
        'Step 2 lecture branch mismatch after creation.'
    Assert-True ($result.fileCheck -eq 'match') `
        'Code file does not match the builder output.'
    Assert-True ($result.promptCheck -eq 'match') `
        'Stored prompt does not match the builder output.'
    Assert-True ($result.clipboardMatchesPrompt -eq $true) `
        'Clipboard does not hold the request prompt.'
    Assert-True ($result.clipboardHasCode -eq $false) `
        'Clipboard contains module source code.'
    Assert-True ($result.clipboardMentionsWin32 -eq $true) `
        'Clipboard prompt does not carry the migration request.'
    Assert-True ($result.clipboardHasLegacyWording -eq $false) `
        'Clipboard prompt contains legacy wording.'

    $attachLogs = @($logs | Where-Object {
        $_ -like 'attach: * (* modules)'
    })
    Assert-True ($attachLogs.Count -eq 2) `
        (
            'Initial and replacement attach logs were not emitted. ' +
            'Actual=' + ($logs -join ' | '))
    foreach ($entry in $attachLogs) {
        Assert-True ($entry -match '\(6 modules\)$') `
            "Attach log module count mismatch: $entry"
    }
    Assert-True (
        $logs -contains ('code file created: ' + $requestPath)) `
        'Code file creation path was not logged.'
    Assert-True (
        ($logs -join "`n") -notmatch
        'Option Explicit|Attribute VB_|Debug\.Print') `
        'Operational logs contain VBA code text.'

    $bytes = [IO.File]::ReadAllBytes($requestPath)
    Assert-True (
        $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF) `
        'Request file does not have a UTF-8 BOM.'
    $actualContent = [IO.File]::ReadAllText(
        $requestPath,
        [Text.Encoding]::UTF8)
    Assert-True (
        $actualContent -notmatch '(?m)^Attribute VB_') `
        'Code file contains an Attribute header.'
    Assert-True ($actualContent.Contains('MODULE INDEX')) `
        'Code file is missing the module index.'
    $bannerCount = @(
        $actualContent -split "`r`n" |
        Where-Object { $_ -match '^={80}$' }).Count
    Assert-True ($bannerCount -eq 14) `
        "Code file banner count mismatch: $bannerCount"
    $moduleHeadingCount = @(
        $actualContent -split "`r`n" |
        Where-Object { $_ -match '^ \S+\.(bas|cls|frm)$' }).Count
    Assert-True ($moduleHeadingCount -eq 6) `
        'Code file does not contain all six modules.'
    Assert-True (
        -not $actualContent.Contains([string][char]0x25A0) -and
        -not $actualContent.Contains([string][char]0x3010)) `
        'Code file contains prose heading markers.'
    Assert-True (
        -not $actualContent.Contains('existing request')) `
        'Request text leaked into the code file.'
    Assert-True (
        -not $actualContent.Contains(
            [string][char]0x73FE + [string][char]0x5728 +
            [string][char]0x7A7A)) `
        'Code file contains the empty-module note.'

    $selected = $false
    for ($attempt = 0; $attempt -lt 150; $attempt++) {
        foreach ($shellWindow in @($shell.Windows())) {
            try {
                foreach ($item in @(
                    $shellWindow.Document.SelectedItems())) {
                    if ([string]::Equals(
                        [IO.Path]::GetFullPath($item.Path),
                        [IO.Path]::GetFullPath($requestPath),
                        [StringComparison]::OrdinalIgnoreCase)) {
                        $selected = $true
                    }
                }
            } catch {
            }
        }
        if ($selected) {
            break
        }
        Start-Sleep -Milliseconds 100
    }
    Assert-True $selected `
        'Explorer did not select the generated request file.'

    Assert-True ($preserved.step -eq 3) `
        'Step 2 next action did not open step 3.'
    Assert-True ($preserved.path -eq $requestPath) `
        'Step navigation did not preserve the request file path.'
    Assert-True ($preserved.modules -eq 6) `
        'Step navigation did not preserve attached modules.'
    Assert-True ([IO.File]::Exists($stepOneScreenshot)) `
        'Step 1 screenshot was not created.'
    Assert-True ([IO.File]::Exists($stepTwoScreenshot)) `
        'Step 2 screenshot was not created.'
} finally {
    foreach ($shellWindow in @($shell.Windows())) {
        if (-not $beforeHandles.ContainsKey(
            [string]$shellWindow.HWND)) {
            try {
                $shellWindow.Quit()
            } catch {
            }
        }
    }

    foreach ($file in Get-ChildItem -LiteralPath $bookDirectory `
        -Filter $requestPattern -File) {
        if (-not $beforeRequestFiles.ContainsKey($file.FullName)) {
            Assert-InsideDirectory $file.FullName $bookDirectory
            [IO.File]::Delete($file.FullName)
        }
    }

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

    if (-not $preserveScreenshots) {
        if ([IO.File]::Exists($stepOneScreenshot)) {
            [IO.File]::Delete($stepOneScreenshot)
        }
        if ([IO.File]::Exists($stepTwoScreenshot)) {
            [IO.File]::Delete($stepTwoScreenshot)
        }
    }
}

Assert-True (-not [IO.Directory]::Exists($cacheDir)) `
    "WebView test cache could not be removed: $cacheDir"
Assert-True (-not [IO.File]::Exists($requestPath)) `
    "Generated request file could not be removed: $requestPath"
if (-not $preserveScreenshots) {
    Assert-True (-not [IO.File]::Exists($stepOneScreenshot)) `
        'Temporary step 1 screenshot could not be removed.'
    Assert-True (-not [IO.File]::Exists($stepTwoScreenshot)) `
        'Temporary step 2 screenshot could not be removed.'
}

Write-Output 'test-p5-webview: PASS'
Write-Output (
    'drop/attach=6 modules, errors=01-05, replacement=reset, ' +
    'empty=stopped, preset=2A, request=BOM+exact, explorer=selected')
if ($preserveScreenshots) {
    Write-Output ('step1Screenshot=' + $stepOneScreenshot)
    Write-Output ('step2Screenshot=' + $stepTwoScreenshot)
} else {
    Write-Output 'screenshots=validated-and-removed'
}
