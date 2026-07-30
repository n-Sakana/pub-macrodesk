param(
    [string]$ProductRoot
)

# The written diff report, opened in the browser engine the reader will
# use and driven by clicking its own controls: the change navigation,
# "changes only", "wrap" and the theme switch. The report carries the
# app's diff code inside itself, so this also proves the bundle runs.

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

if ([string]::IsNullOrEmpty($ProductRoot)) {
    $ProductRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$repoRoot = (Resolve-Path -LiteralPath $ProductRoot).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$libDir = Join-Path $repoRoot 'lib'
$runId = [Guid]::NewGuid().ToString('N')
$cacheDir = Join-Path $testdataRoot ('report-cache-' + $runId)
$reportDir = Join-Path $testdataRoot ('report-out-' + $runId)
Assert-InsideDirectory $cacheDir $testdataRoot
Assert-InsideDirectory $reportDir $testdataRoot

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

$smokeSource = Join-Path $PSScriptRoot 'DiffReportSmoke.cs'
$combined = [IO.File]::ReadAllText($smokeSource, [Text.Encoding]::UTF8)

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

Add-Type -TypeDefinition $combined `
    -ReferencedAssemblies $references `
    -Language CSharp

try {
    try {
        $rawResult = [MacroStudio.Tests.DiffReportSmoke]::Run(
            $repoRoot,
            $cacheDir,
            $reportDir)
    } catch {
        throw $_.Exception.ToString()
    }

    $result = $rawResult | ConvertFrom-Json
    $opened = $result.opened | ConvertFrom-Json
    $changesOnly = $result.changesOnly | ConvertFrom-Json
    $restored = $result.restored | ConvertFrom-Json
    $unwrapped = $result.unwrapped | ConvertFrom-Json
    $wrapped = $result.wrapped | ConvertFrom-Json
    $afterNext = $result.afterNext | ConvertFrom-Json
    $afterPrevious = $result.afterPrevious | ConvertFrom-Json
    $walked = $result.walked | ConvertFrom-Json
$dark = $result.dark | ConvertFrom-Json
    $light = $result.light | ConvertFrom-Json
    $second = $result.second | ConvertFrom-Json

    # ---- the file, and what it opens on ----
    Assert-True ($result.bytes -gt 0) 'The report file is empty.'
    Assert-True ($result.scripts -eq '2') `
        ("The report must carry its data island and its own script " +
            "only: $($result.scripts)")
    Assert-True ($result.modules -eq '2') `
        ("Every module of the workbook must be listed: " +
            "$($result.modules)")
    Assert-True ($opened.rows -gt 0) 'The report shows no diff rows.'
    Assert-True ($opened.changed -gt 0) `
        'The report shows no changed lines.'
    Assert-True ($opened.activeModule -eq 'Main') `
        ("The report opens on the module that changed: " +
            "$($opened.activeModule)")
    Assert-True ($opened.counter -match '^\d+/\d+$') `
        "The change counter is missing: $($opened.counter)"
    Assert-True ($opened.editable -eq 0) `
        'The report must offer nothing to edit.'
    Assert-True ($opened.horizontal -eq $false) `
        'The report must not scroll the page sideways at 1366x768.'

    # ---- no height cap: the document grows to the whole diff ----
    Assert-True ($opened.capped -eq $false) `
        'The diff must not sit inside a scrolling box of its own.'
    Assert-True ($opened.hostHeight -ge $opened.tableHeight) `
        ("The diff container must be as tall as the diff: " +
            "$($opened.hostHeight) vs $($opened.tableHeight)")
    Assert-True ($opened.tableHeight -gt 768) `
        ("This diff must be taller than the window for the check to " +
            "mean anything: $($opened.tableHeight)")

    # ---- changes only ----
    Assert-True ($opened.changesOnlyPressed -eq 'false') `
        'The report must open showing every line.'
    Assert-True ($changesOnly.changesOnlyPressed -eq 'true') `
        'Clicking the toggle did not press it.'
    Assert-True ($changesOnly.rows -lt $opened.rows) `
        ("Changes only must leave rows out: " +
            "$($changesOnly.rows) vs $($opened.rows)")
    Assert-True ($changesOnly.changed -eq $opened.changed) `
        'No changed line may disappear in the changes-only view.'
    Assert-True ($changesOnly.gaps -gt 0) `
        'A collapsed stretch must be offered for expanding.'
    Assert-True ($restored.rows -eq $opened.rows -and
        $restored.gaps -eq 0) `
        'Clicking the toggle again must restore the full listing.'

    # ---- wrap ----
    Assert-True ($opened.wrapPressed -eq 'true' -and
        $opened.wrappedClass -eq $true) `
        'The report must open with wrapping on, like the screen.'
    Assert-True ($unwrapped.wrapPressed -eq 'false' -and
        $unwrapped.wrappedClass -eq $false) `
        'Clicking wrap did not turn it off.'
    Assert-True ($wrapped.wrappedClass -eq $true) `
        'Clicking wrap again did not turn it back on.'

    # ---- previous / next change ----
    Assert-True ($afterNext.jumpTargets -gt 0) `
        'Next change did not mark a row.'
    Assert-True ($afterNext.counter -ne $opened.counter -or
        $afterNext.jumpTargets -gt 0) `
        'Next change did nothing at all.'
    Assert-True ($afterPrevious.counter -eq $opened.counter) `
        ("Previous change must come back to where it started: " +
            "$($afterPrevious.counter) vs $($opened.counter)")

    # ---- the toolbar stays reachable while walking the changes ----
    #
    # Every "next change" scrolls the page. If the bar scrolled away with
    # it, the second click would be a hunt for the button that just moved
    # off the top of the window.
    Assert-True ($walked.scrollY -gt 0) `
        ("Walking the changes must have scrolled the page: " +
            $walked.scrollY)
    Assert-True ($walked.top -eq 0) `
        ("The toolbar left the top of the window: top=" + $walked.top +
            " after scrollY=" + $walked.scrollY)
    Assert-True ($walked.bottom -gt 0) `
        'The toolbar is not on screen after walking the changes.'

    # ---- light / dark ----
    Assert-True ($opened.theme -eq 'light') `
        'The report must open in the light theme.'
    # The switch is a mark next to the other toolbar controls, like the
    # app's own, not a worded button in the page header.
    Assert-True ($walked.themeInToolbar) `
        'The theme switch must sit in the toolbar.'
    Assert-True ($walked.themeText -eq '') `
        ("The theme switch must carry no words: " + $walked.themeText)
    Assert-True ($walked.themeIcons -eq 2) `
        ("The theme switch needs both marks: " + $walked.themeIcons)
    Assert-True ($walked.themeShown -eq 1) `
        ("Exactly one mark shows at a time: " + $walked.themeShown)
    Assert-True ($dark.theme -eq 'dark') `
        'The theme button did not switch to dark.'
    Assert-True ($dark.rows -eq $restored.rows) `
        'Switching the theme must not disturb the diff.'
    Assert-True ($light.theme -eq 'light') `
        'The theme button did not switch back to light.'

    # ---- the report names the two sides for a reader, not a reviewer ----
    $labels = $result.labels | ConvertFrom-Json
    $original = -join @([char]0x5143, [char]0x306E, [char]0x30B3,
        [char]0x30FC, [char]0x30C9)
    $modified = -join @([char]0x6539, [char]0x4FEE, [char]0x5F8C,
        [char]0x306E, [char]0x30B3, [char]0x30FC, [char]0x30C9)
    $pasted = -join @([char]0x8CBC, [char]0x308A, [char]0x4ED8,
        [char]0x3051, [char]0x305F)
    foreach ($text in @($labels.caption, $labels.codeNote)) {
        Assert-True (([string]$text).Length -gt 0) `
            'The report lost its table labels.'
        Assert-True (([string]$text).IndexOf($original) -ge 0) `
            ('A report label must name the original code: ' + $text)
        Assert-True (([string]$text).IndexOf($modified) -ge 0) `
            ('A report label must name the modified code: ' + $text)
        Assert-True (([string]$text).IndexOf($pasted) -lt 0) `
            ('A report label still uses the review screen wording: ' +
                $text)
    }

    # ---- a module with no changes still lays out ----
    #
    # An unchanged module puts a second note beside the badge. If the
    # left group is allowed to be squeezed, that note keeps its width
    # anyway and paints over the buttons next to it.
    $secondToolbar = $result.secondToolbar | ConvertFrom-Json
    Write-Output ('toolbar(unchanged, narrow): ' + $result.secondToolbar)
    Assert-True ($secondToolbar.notes -ge 2) `
        ("An unchanged module must carry its note: " +
            $secondToolbar.notes)
    Assert-True (
        $secondToolbar.lastNoteRight -le $secondToolbar.actionsLeft) `
        ("The note runs over the buttons: note ends at " +
            $secondToolbar.lastNoteRight + ", buttons start at " +
            $secondToolbar.actionsLeft)
    Assert-True ($secondToolbar.clipped -le 0) `
        ("The left group is being squeezed and clips its own text by " +
            $secondToolbar.clipped + "px")

    # ---- the module list opens another module ----
    Assert-True ($second.activeModule -eq 'ThisWorkbook') `
        ("Choosing a module from the list must open it: " +
            "$($second.activeModule)")
    Assert-True ($second.changed -eq 0) `
        'An untouched module has no changed lines to show.'
    Assert-True ($second.editable -eq 0) `
        'No screen of the report may offer an editing control.'
} finally {
    # The browser lets go of its cache a moment after the window closes.
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
    foreach ($path in @($reportDir, $cacheDir)) {
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
            if (-not [IO.Directory]::Exists($path)) {
                break
            }
            try {
                Assert-InsideDirectory $path $testdataRoot
                [IO.Directory]::Delete($path, $true)
            } catch {
                Start-Sleep -Milliseconds 100
            }
        }
    }
}

Write-Output 'test-diff-report-webview: PASS'
Write-Output (
    ('rows {0}->{1} (changes only), wrap {2}->{3}, theme light->{4}, ' +
        'diff {5}px uncapped, scripts {6}') -f `
    $opened.rows,
    $changesOnly.rows,
    $opened.wrapPressed,
    $unwrapped.wrapPressed,
    $dark.theme,
    $opened.tableHeight,
    $result.scripts)
