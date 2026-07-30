param(
    [string]$BookPath,
    [string]$ProductRoot,
    [string]$LightScreenshotPath,
    [string]$DarkScreenshotPath
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
if ([string]::IsNullOrEmpty($ProductRoot)) {
    $ProductRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$repoRoot = (Resolve-Path -LiteralPath $ProductRoot).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$libDir = Join-Path $repoRoot 'lib'
$cacheDir = Join-Path $testdataRoot (
    'flow-cache-' + [Guid]::NewGuid().ToString('N'))
$preserveScreenshots =
    -not [string]::IsNullOrEmpty($LightScreenshotPath) -and
    -not [string]::IsNullOrEmpty($DarkScreenshotPath)

if ([string]::IsNullOrEmpty($LightScreenshotPath)) {
    $LightScreenshotPath = Join-Path $testdataRoot (
        'flow-light-' + [Guid]::NewGuid().ToString('N') + '.png')
}
if ([string]::IsNullOrEmpty($DarkScreenshotPath)) {
    $DarkScreenshotPath = Join-Path $testdataRoot (
        'flow-dark-' + [Guid]::NewGuid().ToString('N') + '.png')
}
$lightScreenshot = [IO.Path]::GetFullPath($LightScreenshotPath)
$darkScreenshot = [IO.Path]::GetFullPath($DarkScreenshotPath)
Assert-InsideDirectory $cacheDir $testdataRoot
Assert-InsideDirectory $lightScreenshot $testdataRoot
Assert-InsideDirectory $darkScreenshot $testdataRoot

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
$smokeSource = Join-Path $PSScriptRoot 'P10FlowSmoke.cs'
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

$runFolder = ''
try {
    try {
        $rawResult = [MacroStudio.Tests.P10FlowSmoke]::Run(
            $repoRoot,
            $resolvedBookPath,
            $cacheDir,
            $lightScreenshot,
            $darkScreenshot)
    } catch {
        throw $_.Exception.ToString()
    }

    $result = $rawResult | ConvertFrom-Json
    $start = $result.start | ConvertFrom-Json
    $attached = $result.attached | ConvertFrom-Json
    $book = $result.book | ConvertFrom-Json
    $mode = $result.mode | ConvertFrom-Json
    $modeChosen = $result.modeChosen | ConvertFrom-Json
    $dropScreen = $result.dropScreen | ConvertFrom-Json
    $backToStart = $result.backToStart | ConvertFrom-Json
    $purpose = $result.purpose | ConvertFrom-Json
    $purposeChosen = $result.purposeChosen | ConvertFrom-Json
    $request = $result.request | ConvertFrom-Json
    $requestOpen = $result.requestOpen | ConvertFrom-Json
    $handoff = $result.handoff | ConvertFrom-Json
    $handoffReady = $result.handoffReady | ConvertFrom-Json
    $intakeScreen = $result.intakeScreen | ConvertFrom-Json
    $refused = $result.refused | ConvertFrom-Json
    $intake = $result.intake | ConvertFrom-Json
    $review = $result.review | ConvertFrom-Json
    $diff = $result.diff | ConvertFrom-Json
    $finish = $result.finish | ConvertFrom-Json
    $accepted = $result.accepted | ConvertFrom-Json
    $summary = $result.summary | ConvertFrom-Json
    $done = $result.done | ConvertFrom-Json
    $finalShell = $result.finalShell | ConvertFrom-Json
    $runFolder = [string]$result.runFolder
    $requestId = [string]$result.requestId
    # 'settings': the vague label a disclosure trigger must not use.
    # Joined rather than added: adding two [char] values adds numbers,
    # which turned this check into a comparison against "58823".
    $vagueLabel = -join @([char]0x8A2D, [char]0x5B9A)

    # The shell: four progress steps, and one fixed pair of buttons
    # that never changes size or position.
    foreach ($shell in @($start, $finalShell)) {
        Assert-True (-not $shell.documentScrollX) `
            'The app scrolled horizontally.'
        Assert-True (-not $shell.documentScrollY) `
            'The app scrolled vertically.'
        Assert-True $shell.footerVisible `
            'The fixed footer left the viewport.'
        Assert-True ($shell.buttons -eq 2 -and $shell.sameWidth) `
            'Back and next must stay the same size, side by side.'
        # The bar keeps the same width from the first screen: only the
        # steps inside it fill in once the run's purpose is known.
        Assert-True ($shell.progressSlots -eq 4) `
            'The progress bar must always reserve four columns.'
        Assert-True ($shell.progress -ge 1 -and $shell.progress -le 4) `
            'The progress bar must show the steps that are known.'
    }

    # What the run is for is the first decision, before any workbook,
    # and it does not advance the flow by itself.
    Assert-True ($mode.screen -eq 0) `
        'The flow must open on the work choice.'
    # This runner is ASCII only, so Japanese wording is spelled out in
    # code points and joined: adding [char] values would add numbers.
    $expectedModeTitle = -join @(
        [char]0x4F5C, [char]0x696D, [char]0x3092, [char]0x9078,
        [char]0x3093, [char]0x3067, [char]0x304F, [char]0x3060,
        [char]0x3055, [char]0x3044)
    Assert-True ($mode.title -ceq $expectedModeTitle) `
        ('The opening screen must ask what the work is: ' + $mode.title)
    Assert-True (@($mode.cards).Count -eq 2) `
        'The opening screen must offer exactly two choices.'
    Assert-True (-not $mode.nextReady) `
        'The opening screen must wait for a choice.'
    Assert-True ($mode.backDisabled) `
        'The opening screen has nothing to go back to.'

    # No workbook has been read yet, so nothing on this screen may point
    # at one: read literally, "this macro" would be MacroStudio itself.
    $thisMacro = -join @(
        [char]0x3053, [char]0x306E, [char]0x30DE, [char]0x30AF,
        [char]0x30ED)
    $thisBook = -join @(
        [char]0x3053, [char]0x306E, [char]0x30D6, [char]0x30C3,
        [char]0x30AF)
    foreach ($phrase in @($thisMacro, $thisBook)) {
        Assert-True (-not ([string]$mode.text).Contains($phrase)) `
            ('The opening screen points at a workbook it has not read: ' +
                $phrase)
    }
    Assert-True ($modeChosen.stillHere -eq 0) `
        'Choosing the work must not advance the screen by itself.'
    Assert-True ($modeChosen.steps -eq 4) `
        'A refactoring run must show four steps.'
    Assert-True ($modeChosen.nextReady) `
        'A chosen mode must enable next.'

    Assert-True ($dropScreen.screen -eq 1) `
        'The workbook screen must follow the work choice.'
    Assert-True (-not $dropScreen.nextReady) `
        'The workbook screen must wait for a workbook.'
    Assert-True (-not $dropScreen.backDisabled) `
        'The workbook screen must be able to go back.'

    Assert-True ($attached.screen -eq 1) `
        'Loading a workbook must stay on the workbook screen.'
    Assert-True ($attached.mode -ceq 'refactor') `
        'Loading a workbook must not drop the chosen work.'
    Assert-True ($attached.modules -gt 0) `
        'No modules were read from the workbook.'
    Assert-True ($attached.nextReady) `
        'A loaded workbook must enable next.'
    Assert-True (-not $attached.backDisabled) `
        'The workbook screen keeps its way back.'

    Assert-True ($book.screen -eq 2) `
        'The read result screen is missing.'
    Assert-True (@($book.stats).Count -ge 2) `
        'The read result must show what was read.'

    # Back walks the new order in reverse and keeps what was decided.
    Assert-True ($backToStart.screen -eq 0) `
        'Back must reach the work choice again.'
    Assert-True ($backToStart.mode -ceq 'refactor' -and
        $backToStart.book) `
        'Going back must keep the work and the workbook.'

    # One screen, one decision: the purpose is chosen by hand and does
    # not advance the flow by itself.
    Assert-True ($purpose.cards -ge 3 -and -not $purpose.nextReady) `
        'The purpose screen must offer every preset and wait.'

    # The line under each preset name is the file's own description
    # section, read here from the shipped presets. It used to be taken
    # from the request, which is written for the chat AI and wraps
    # wherever the column ran out, so the card showed somebody else's
    # sentence with its tail cut off.
    $fullStop = [char]0x3002
    $danglingMarks = @(
        [char]0x3001,
        [char]0x30FB,
        [char]0xFF0C,
        [char]0x300C,
        [char]0xFF08)
    $descriptionHeading = '## ' + (-join [char[]](0x8AAC, 0x660E))
    $modeHeading = '## ' + (-join [char[]](0x7528, 0x9014))
    $diagnoseWord = -join [char[]](0x8A3A, 0x65AD)
    $expected = @{ refactor = @(); diagnose = @() }
    $presetFiles = @(Get-ChildItem `
        (Join-Path $repoRoot 'presets') -Filter '*.md' |
        Sort-Object `
            @{ Expression = {
                if ($_.Name -match '^(\d+)_') {
                    [int]$Matches[1]
                } else {
                    [int]::MaxValue
                } } },
            Name)
    Assert-True ($presetFiles.Count -ge 6) `
        'The shipped presets are missing.'
    foreach ($file in $presetFiles) {
        $text = [regex]::Replace(
            [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8),
            '<!--[\s\S]*?-->',
            '')
        $sections = @{}
        $current = ''
        foreach ($line in ($text -split "`r`n|`n")) {
            if ($line -like '## *') {
                $current = $line.Trim()
                $sections[$current] = @()
            } elseif ($current -ne '' -and $line.Trim() -ne '') {
                $sections[$current] += $line.Trim()
            }
        }
        Assert-True ($sections.ContainsKey($descriptionHeading)) `
            ('A shipped preset declares no card line: ' + $file.Name)
        # A wrap inside Japanese prose is not a space; between two Latin
        # words it is.
        $joined = ''
        foreach ($line in $sections[$descriptionHeading]) {
            if ($joined -eq '') {
                $joined = $line
                continue
            }
            if (($joined[$joined.Length - 1] -match '[0-9A-Za-z]') -and
                ($line[0] -match '[0-9A-Za-z]')) {
                $joined += ' '
            }
            $joined += $line
        }
        $route = 'refactor'
        if ($sections.ContainsKey($modeHeading) -and
            (@($sections[$modeHeading]) -join '') -ceq $diagnoseWord) {
            $route = 'diagnose'
        }
        $expected[$route] += $joined
    }

    # Both routes list their own presets through the same card builder.
    $diagnosePurpose = $result.diagnosePurpose | ConvertFrom-Json
    foreach ($route in @('refactor', 'diagnose')) {
        $screen = if ($route -eq 'refactor') {
            $purpose
        } else {
            $diagnosePurpose
        }
        $shown = @($screen.descriptions | ForEach-Object {
            ([string]$_).Trim() })
        $declared = @($expected[$route])
        Assert-True ($declared.Count -ge 3) `
            ("The $route route ships too few presets: " + $declared.Count)
        Assert-True ($shown.Count -eq $declared.Count) `
            ("The $route purpose screen showed " + $shown.Count +
                ' lines for ' + $declared.Count + ' presets.')
        for ($i = 0; $i -lt $declared.Count; $i++) {
            Assert-True ($shown[$i] -ceq $declared[$i]) `
                ("The $route purpose screen shows " + $shown[$i] +
                    ' instead of the declared ' + $declared[$i])
            Assert-True ($shown[$i].EndsWith($fullStop)) `
                ('A preset card line is cut mid-sentence: ' + $shown[$i])
            foreach ($mark in $danglingMarks) {
                Assert-True (-not $shown[$i].EndsWith($mark)) `
                    ('A preset card line ends on a dangling mark: ' +
                        $shown[$i])
            }
        }
    }

    Assert-True ($purposeChosen.stillHere -eq 3) `
        'Choosing a purpose must not advance the screen by itself.'
    Assert-True ($purposeChosen.selected -eq 1) `
        'Choosing a purpose must mark exactly one card.'
    Assert-True (
        $purposeChosen.requestChars -gt 0 -and
        $purposeChosen.outputRules) `
        'The purpose must fill the request and the output rules.'
    Assert-True (-not $purposeChosen.placeholderLeft) `
        'The request id placeholder must be substituted.'
    Assert-True ($purposeChosen.nextReady) `
        'A chosen purpose must enable next.'
    Assert-True (
        $requestId -match
        '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') `
        "The request id is not a version 4 UUID: $requestId"

    # Progressive disclosure: the request text is offered, not imposed.
    Assert-True ($request.closed -eq 'false') `
        'The request editor must start closed.'
    Assert-True (
        ([string]$request.trigger).Length -gt 0 -and
        ([string]$request.trigger) -notmatch $vagueLabel) `
        'The disclosure must say what it opens.'
    Assert-True ($request.nextReady) `
        'A prepared request must enable next without opening it.'
    Assert-True ($requestOpen.editor -and $requestOpen.chars -gt 0) `
        'Opening the disclosure must reveal the request text.'

    Assert-True ($handoff.cards -eq 2) `
        'The hand-off screen must show both steps.'
    Assert-True (
        @($handoff.chips) -contains 'request.md' -and
        @($handoff.chips) -contains 'source-code.md') `
        'The hand-off must name the files it created.'
    Assert-True (-not $handoff.nextReady) `
        'The hand-off must wait for the copy and the folder.'
    Assert-True ($handoffReady.nextReady) `
        'Copying and opening the folder must enable next.'
    Assert-True ($handoffReady.copyDone -eq 2) `
        'Both hand-off cards must show their done state.'
    Assert-True ($result.clipboardIsPrompt) `
        'The clipboard must hold the generated request.'
    Assert-True ($result.promptCarriesRequestId) `
        'The copied request must carry this run''s sentinels.'

    # The output folder contract.
    Assert-True (-not [string]::IsNullOrEmpty($runFolder)) `
        'No run folder was created.'
    Assert-True (
        [IO.Path]::GetFileName(
            [IO.Path]::GetDirectoryName($runFolder)) -ceq 'MacroStudio') `
        'The run folder must sit in a MacroStudio folder.'
    Assert-True (
        [IO.Path]::GetDirectoryName(
            [IO.Path]::GetDirectoryName($runFolder)) -ceq
        [IO.Path]::GetDirectoryName($resolvedBookPath)) `
        'The MacroStudio folder must sit beside the original workbook.'
    Assert-True (
        [IO.Path]::GetFileName($runFolder) -match
        ('^' + [regex]::Escape(
            [IO.Path]::GetFileNameWithoutExtension($resolvedBookPath)) +
            '_\d{8}_\d{6}$')) `
        "Run folder name mismatch: $runFolder"
    Assert-True ([IO.File]::Exists($resolvedBookPath)) `
        'The original workbook must stay where it was.'

    # The intake screen is one press: no tree, no per-module pasting.
    Assert-True (
        @($intakeScreen.actions).Count -eq 1 -and
        @($intakeScreen.actions)[0] -ceq 'import-response') `
        'The intake screen must offer exactly one action.'
    Assert-True ($intakeScreen.moduleLists -eq 0) `
        'The intake screen must not show a module list.'
    Assert-True ($intakeScreen.textareas -eq 0) `
        'The intake screen must not ask for pasted text per module.'

    # A foreign answer is refused, in words the user can act on.
    Assert-True ($refused.imported -eq 0) `
        'An answer without sentinels must not be applied.'
    Assert-True (-not $refused.nextReady) `
        'A refused answer must not open the next screen.'
    Assert-True (
        ([string]$refused.message).Length -gt 0 -and
        ([string]$refused.message) -notmatch
            '(Error|Exception|undefined|null|E-[A-Z]+-[0-9]+)') `
        "The refusal message is not plain language: $($refused.message)"

    # The real answer arrives as one package.
    Assert-True ($intake.imported -eq 2) `
        'Both modules in the package must be taken in at once.'
    Assert-True (
        $intake.result.total -eq 2 -and
        $intake.result.existing -eq 1 -and
        $intake.result.added -eq 1) `
        'The intake summary must count existing and added modules.'
    Assert-True ($intake.added -eq 1) `
        'The package must add its new module.'
    Assert-True ($intake.nextReady) `
        'An imported package must enable next.'
    Assert-True (
        ([string]$intake.summary).Length -gt 0 -and
        ([string]$intake.summary) -match 'FlowSmokeHelpers') `
        'The answer''s own summary must be taken in with it.'
    Assert-True ($intake.summaryClosed -eq 'false') `
        'The summary must be offered, not imposed.'

    # The review screen leads with a summary, not with code.
    Assert-True (([string]$review.headline).Length -gt 0) `
        'The review screen must summarise what came in.'
    Assert-True ($review.closed -eq 'false') `
        'The diff must start closed on the review screen.'
    Assert-True (
        ([string]$review.trigger).Length -gt 0 -and
        ([string]$review.trigger) -notmatch $vagueLabel) `
        'The diff disclosure must say what it opens.'
    Assert-True ($review.decide -eq 0) `
        'Taking the answer in is the decision: no second accept step.'
    Assert-True ($review.accepted -eq 2) `
        'Every changed module that came in is written back.'
    Assert-True ($review.nextReady) `
        'A reviewed package can go straight to the build.'

    # The production inline diff is used as it is.
    Assert-True ($diff.tree -eq 2) `
        'The diff must list every imported module in its tree.'
    Assert-True ($diff.groups -ge 1) `
        'The diff tree must group modules by kind.'
    Assert-True ($diff.columns -eq 4) `
        'The diff must keep its four inline columns.'
    Assert-True ($diff.twoColumn -eq 0) `
        'The two-column diff must not come back.'
    Assert-True (
        $diff.markers -gt 0 -and
        ($diff.removed + $diff.added) -gt 0) `
        'The diff must show marked added and removed rows.'
    Assert-True ($diff.toolbar -ge 5) `
        'The diff toolbar lost its actions.'
    Assert-True ($diff.scrollsInside) `
        'The diff must scroll inside its own area.'

    Assert-True (
        $accepted.nextReady -and
        $accepted.accepted -eq 2) `
        'The reviewed package must enable next.'

    Assert-True (@($summary.values).Count -ge 3) `
        'The output screen must summarise what will be written.'
    # The names carry the workbook's own base name and the run's date, so
    # they are derived from the workbook this run was given.
    $bookBase = [IO.Path]::GetFileNameWithoutExtension($resolvedBookPath)
    $bookExtension = [IO.Path]::GetExtension($resolvedBookPath)
    $expectedDiffName = $bookBase + '-Diff-Report-' +
        [DateTime]::Now.ToString('yyyyMMdd') + '.html'
    $expectedOutputName = $bookBase + '-Modified-' +
        [DateTime]::Now.ToString('yyyyMMdd') + $bookExtension
    Assert-True (
        @($summary.files) -contains 'request.md' -and
        @($summary.files) -contains 'source-code.md' -and
        @($summary.files) -contains 'result.md' -and
        @($summary.files) -contains $expectedDiffName -and
        @($summary.files) -contains $expectedOutputName) `
        ('The output screen must show the run folder contract: ' +
            (@($summary.files) -join ', '))

    Assert-True (
        $done.outputPath.StartsWith(
            $runFolder,
            [StringComparison]::OrdinalIgnoreCase)) `
        'The rebuilt workbook must land in the run folder.'
    Assert-True (
        $done.diffPath.StartsWith(
            $runFolder,
            [StringComparison]::OrdinalIgnoreCase)) `
        'The diff report must land in the run folder.'
    Assert-True ($done.openButtons -eq 1) `
        'The last screen needs exactly one open-folder button.'
    Assert-True ($done.copyButtons -eq 0) `
        'No screen may offer a path copy button.'
    Assert-True ($finish.nextButtons -eq 0) `
        'The last screen must not leave a dead next button.'
    Assert-True (([string]$finish.label).Length -gt 0) `
        'The last screen must offer a finish button.'
    Assert-True (
        -not [string]::IsNullOrEmpty([string]$done.resultPath)) `
        'The run must write the summary memo.'
    foreach ($name in @(
        'request.md',
        'source-code.md',
        [IO.Path]::GetFileName($done.outputPath),
        [IO.Path]::GetFileName($done.diffPath),
        'result.md')) {
        Assert-True (@($done.rows) -contains $name) `
            "The result list is missing: $name"
        Assert-True (
            [IO.File]::Exists((Join-Path $runFolder $name))) `
            "The run folder is missing: $name"
    }
    Assert-True (
        [IO.Path]::GetFileName($done.outputPath) -ceq
        [string]$result.output) `
        'The build must use the name shown on the output screen.'

    # The written report is the review screen, read-only: it renders with
    # the app's own diff code, so rows appear only if that bundle ran.
    $report = $result.report | ConvertFrom-Json
    Assert-True (
        $report.modules -ge 3 -and
        $report.markers -gt 0) `
        'The diff report must open with its module list and its rows.'
    Assert-True ($report.toolbar -ge 4) `
        ('The report toolbar lost its controls: ' + $report.toolbar)
    Assert-True ($report.theme -ceq 'light') `
        'The report must open in the light theme.'
    Assert-True ($report.editable -eq 0) `
        'The report must offer nothing to edit.'
    Assert-True ($report.external -eq 0) `
        'The diff report must stay self-contained.'
    Assert-True (-not $report.horizontal) `
        'The diff report must not scroll the page sideways.'

    foreach ($path in @($lightScreenshot, $darkScreenshot)) {
        Assert-True ([IO.File]::Exists($path)) `
            "Flow screenshot was not created: $path"
        $signature = New-Object byte[] 4
        $stream = [IO.File]::OpenRead($path)
        try {
            [void]$stream.Read($signature, 0, 4)
        } finally {
            $stream.Dispose()
        }
        Assert-True (
            $signature[0] -eq 0x89 -and
            $signature[1] -eq 0x50) `
            "Flow screenshot is not a PNG: $path"
    }

    Write-Output 'test-flow-webview: PASS'
    Write-Output (
        'screens=0-9, runFolder=' +
        [IO.Path]::GetFileName($runFolder) +
        ', package=2 modules (1 changed, 1 added)' +
        ', artifacts=4, diff=inline, footer=fixed')
} finally {
    if (-not [string]::IsNullOrEmpty($runFolder) -and
        [IO.Directory]::Exists($runFolder)) {
        Assert-InsideDirectory $runFolder $testdataRoot
        [IO.Directory]::Delete($runFolder, $true)
        $macroRoot = [IO.Path]::GetDirectoryName($runFolder)
        if ([IO.Directory]::Exists($macroRoot) -and
            @([IO.Directory]::GetFileSystemEntries(
                $macroRoot)).Count -eq 0) {
            [IO.Directory]::Delete($macroRoot)
        }
    }
    if (-not $preserveScreenshots) {
        foreach ($path in @($lightScreenshot, $darkScreenshot)) {
            if ([IO.File]::Exists($path)) {
                Assert-InsideDirectory $path $testdataRoot
                [IO.File]::Delete($path)
            }
        }
    }

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        if (-not [IO.Directory]::Exists($cacheDir)) {
            break
        }
        try {
            Assert-InsideDirectory $cacheDir $testdataRoot
            [IO.Directory]::Delete($cacheDir, $true)
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
}
