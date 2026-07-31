param(
    [string]$BookPath,
    [string]$ProductRoot,
    [string]$DumpPath
)

# Every box the flow offers, typed into in the real runtime.
#
# The check is not "did the characters arrive" - they always did. It is
# "was the box still there afterwards": the same element, still focused,
# with the caret where the person left it. A screen that is rebuilt on
# each keystroke passes the first check and fails this one, which is
# exactly what someone typing feels.

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

# One box, every step of it. Nothing may have replaced the element and
# nothing may have taken the focus away from it.
function Assert-BoxSurvived {
    param(
        $Report,
        [string]$Label
    )

    Assert-True (-not $Report.missing) `
        "$Label : the box was not on the screen at all."
    Assert-True ([bool]$Report.focusTaken) `
        ("$Label : the box could not take the focus to begin with (" +
            ($Report.why | ConvertTo-Json -Compress) + ').')

    $groups = @(
        @('typed', $Report.typed),
        @('composed', $Report.composed),
        @('pasted', $Report.pasted),
        @('replaced', $Report.replaced))

    foreach ($group in $groups) {
        $name = $group[0]
        foreach ($step in $group[1]) {
            Assert-True ([bool]$step.survived) `
                ("$Label / $name / " + $step.step +
                    ' : the box was replaced by another element.')
            Assert-True ([bool]$step.focused) `
                ("$Label / $name / " + $step.step +
                    ' : the focus left the box (it went to ' +
                    [string]$step.active + ').')
        }
    }

    # Typing one character at a time must move the caret one place at a
    # time. A caret that snaps back to 0 is a rebuilt box.
    $index = 0
    foreach ($step in $Report.typed) {
        $index += 1
        Assert-True ($step.caret -eq $index) `
            ("$Label : after " + $index + ' characters the caret was at ' +
                [string]$step.caret + '.')
    }
}

function Assert-ToggleSurvived {
    param(
        $Report,
        [string]$Label
    )

    Assert-True (-not $Report.missing) `
        "$Label : the option was not on the screen."
    Assert-True ([bool]$Report.focusTaken) `
        "$Label : the option could not take the focus."
    foreach ($step in $Report.steps) {
        Assert-True ([bool]$step.survived) `
            ("$Label / " + $step.step +
                ' : the option was replaced by another element.')
        Assert-True ([bool]$step.focused) `
            ("$Label / " + $step.step +
                ' : the focus left the option (it went to ' +
                [string]$step.active + ').')
    }
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
    'focus-cache-' + [Guid]::NewGuid().ToString('N'))
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
$smokeSource = Join-Path $PSScriptRoot 'EditorFocusSmoke.cs'
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
        $rawResult = [MacroStudio.Tests.EditorFocusSmoke]::Run(
            $repoRoot,
            $cacheDir,
            $resolvedBookPath)
    } catch {
        throw $_.Exception.ToString()
    }

    if (-not [string]::IsNullOrEmpty($DumpPath)) {
        [IO.File]::WriteAllText($DumpPath, $rawResult)
    }

    $result = $rawResult | ConvertFrom-Json
    $detailed = $result.detailed | ConvertFrom-Json
    $questions = $result.questions | ConvertFrom-Json
    $simple = $result.simple | ConvertFrom-Json

    if ($detailed.runFolder) {
        $runFolders += [string]$detailed.runFolder
    }

    # 'Xabc' followed by the settled word and the pasted one: what is
    # left after typing, composing, pasting and replacing a selection.
    $expected = 'Xabc' + (-join @(
        [char]0x6F22, [char]0x5B57, [char]0x8CBC, [char]0x4ED8))

    $boxes = @(
        @('request-text (detailed)', ($detailed.requestText |
            ConvertFrom-Json)),
        @('output-name (detailed)', ($detailed.outputName |
            ConvertFrom-Json)),
        @('answer-0 (questions)', ($questions.answer |
            ConvertFrom-Json)),
        @('simple-request-input (simple)', ($simple.requestText |
            ConvertFrom-Json)))

    foreach ($box in $boxes) {
        Assert-BoxSurvived $box[1] $box[0]
        Assert-True (([string]$box[1].finalValue) -eq $expected) `
            ($box[0] + ' : the text ended up as "' +
                [string]$box[1].finalValue + '" instead of "' +
                $expected + '".')
    }

    # Keeping the element alive must not have cost the update. What was
    # typed has to be in the state, and the lines worked out from the
    # state have to show it.
    $derived = $detailed.derived | ConvertFrom-Json
    Assert-True (([string]$derived.boxText) -eq $expected) `
        'The request box does not hold what was typed into it.'
    Assert-True (([string]$derived.stateText) -eq $expected) `
        ('What was typed never reached the state: "' +
            [string]$derived.stateText + '".')
    $countMark = -join @([char]0x6587, [char]0x5B57)
    Assert-True (
        ([string]$derived.note) -eq
            ([string]$expected.Length + $countMark)) `
        ('The character count did not follow the typing: "' +
            [string]$derived.note + '".')
    Assert-True (([string]$derived.preview) -eq $expected) `
        ('The preview line did not follow the typing: "' +
            [string]$derived.preview + '".')

    Assert-True (([string]$detailed.outputNameState) -eq $expected) `
        ('The file name never reached the state: "' +
            [string]$detailed.outputNameState + '".')
    Assert-True (([string]$questions.answerState) -eq $expected) `
        ('The answer never reached the state: "' +
            [string]$questions.answerState + '".')
    Assert-True (([string]$simple.requestState) -eq $expected) `
        ('The short way never reached the state: "' +
            [string]$simple.requestState + '".')

    Assert-ToggleSurvived ($detailed.splitOption | ConvertFrom-Json) `
        'split-output (detailed)'
    Assert-ToggleSurvived ($simple.splitOption | ConvertFrom-Json) `
        'split-output (simple)'

    Assert-True ($questions.questionCount -gt 0) `
        'The preset that asks questions must have asked at least one.'

    Write-Output 'test-editor-focus: PASS'
    Write-Output (
        'every box kept its element, its focus and its caret through ' +
        'typing, IME composition, pasting and replacing a selection')
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
            Write-Output (
                'note: the WebView2 cache folder is still in use: ' +
                $cacheDir)
        }
    }
}
