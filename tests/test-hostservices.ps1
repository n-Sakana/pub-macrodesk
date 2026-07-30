param(
    [string]$BookPath,
    [switch]$TestExplorer
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-HostSource {
    $names = @(
        '04_HostServices.cs',
        '05_Ole2.cs',
        '06_VbaCompression.cs',
        '07_VbaProject.cs',
        '08_BookIO.cs'
    )
    $combined = ($names | ForEach-Object {
        $path = Join-Path (Join-Path $PSScriptRoot '..\src') $_
        [IO.File]::ReadAllText(
            (Resolve-Path -LiteralPath $path),
            [Text.Encoding]::UTF8)
    }) -join "`n"

    $usingPattern = '(?m)^\s*using\s+[\w][\w.]*\s*;'
    $usings = [regex]::Matches($combined, $usingPattern) |
        ForEach-Object { $_.Value.Trim() } |
        Sort-Object -Unique
    $body = $combined -replace $usingPattern, ''
    return ($usings -join "`n") + "`n`n" + $body
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

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$references = @(
    [System.Windows.Window].Assembly.Location
    [System.Windows.UIElement].Assembly.Location
    [System.Windows.DependencyObject].Assembly.Location
    [System.Xaml.XamlReader].Assembly.Location
    'System.IO.Compression',
    'System.IO.Compression.FileSystem'
)
Add-Type -TypeDefinition (Get-HostSource) `
    -ReferencedAssemblies $references `
    -Language CSharp

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$service = New-Object MacroStudio.HostServices($null, $repoRoot)

$appInfo = $service.GetAppInfo()
Assert-True ($appInfo['version'] -eq 'beta 1.0.0') `
    'Application version mismatch.'
$expectedBuildFileLabel = [IO.File]::ReadAllText(
    (Join-Path $repoRoot 'assets\messages\build-file-label.txt'),
    [Text.Encoding]::UTF8).Trim()
Assert-True (
    $appInfo['buildFileLabel'] -eq $expectedBuildFileLabel) `
    'Build file label mismatch.'
$expectedRequestTemplate = [IO.File]::ReadAllText(
    (Join-Path $repoRoot 'templates\request-template.txt'),
    [Text.Encoding]::UTF8)
Assert-True (
    $service.ReadRequestTemplate()['content'] -ceq
    $expectedRequestTemplate) `
    'Request template content mismatch.'

$attached = $service.AttachBook($resolvedBookPath)
$book = $attached['book']
$modules = $attached['modules']
Assert-True ($book['path'] -eq $resolvedBookPath) `
    'Attached book path mismatch.'
Assert-True ($book['ext'] -eq '.xlsm') `
    'Attached book extension mismatch.'
Assert-True ($book['totalLines'] -eq 19) `
    'Attached book total line count mismatch.'
Assert-True ($modules.Count -eq 6) `
    'Attached module count mismatch.'

$expectedNames = @(
    'Sheet1',
    'ThisWorkbook',
    'AppController',
    'SystemInfo',
    'TimerUtils',
    'WindowUtils'
)
$expectedTypes = @(
    'document',
    'document',
    'standard',
    'standard',
    'standard',
    'standard'
)
$expectedLines = @(0, 0, 2, 5, 4, 8)
for ($index = 0; $index -lt $modules.Count; $index++) {
    Assert-True ($modules[$index]['name'] -eq $expectedNames[$index]) `
        "Module name mismatch at $index."
    Assert-True ($modules[$index]['type'] -eq $expectedTypes[$index]) `
        "Module type mismatch at $index."
    Assert-True ($modules[$index]['lineCount'] -eq $expectedLines[$index]) `
        "Module line count mismatch at $index."
    Assert-True (
        -not [string]::IsNullOrEmpty($modules[$index]['typeLabel'])) `
        "Module type label is empty at $index."
}

# A damaged container must still hand the real VBA source to the UI:
# a warning is allowed, an empty module list is not.
$damagedAttachPath = Join-Path $testdataRoot (
    'host-damaged-' + [Guid]::NewGuid().ToString('N') + '.xlsm')
Assert-InsideDirectory $damagedAttachPath $testdataRoot
try {
    [byte[]]$damagedBytes = [IO.File]::ReadAllBytes($resolvedBookPath)
    for ($index = 0; $index -lt $damagedBytes.Length - 3; $index++) {
        if ($damagedBytes[$index] -eq 0x50 -and
            $damagedBytes[$index + 1] -eq 0x4B -and
            $damagedBytes[$index + 2] -eq 0x05 -and
            $damagedBytes[$index + 3] -eq 0x06) {
            $damagedBytes[$index + 2] = 0x00
            $damagedBytes[$index + 3] = 0x00
        }
    }
    [IO.File]::WriteAllBytes($damagedAttachPath, $damagedBytes)
    $damagedAttached = $service.AttachBook($damagedAttachPath)
    Assert-True ($damagedAttached['warning'] -eq $true) `
        'A damaged workbook did not report a read warning.'
    Assert-True ($damagedAttached['modules'].Count -eq $modules.Count) `
        'A damaged workbook returned an empty module list.'
    for ($index = 0; $index -lt $modules.Count; $index++) {
        Assert-True (
            $damagedAttached['modules'][$index]['code'] -ceq
            $modules[$index]['code']) `
            "Damaged-workbook VBA source changed at $index."
    }
} finally {
    Assert-InsideDirectory $damagedAttachPath $testdataRoot
    if ([IO.File]::Exists($damagedAttachPath)) {
        [IO.File]::Delete($damagedAttachPath)
    }
}

# A workbook that another process holds open (Excel) is still read.
$held = [IO.File]::Open(
    $resolvedBookPath,
    [IO.FileMode]::Open,
    [IO.FileAccess]::Read,
    [IO.FileShare]::ReadWrite)
try {
    $sharedAttached = $service.AttachBook($resolvedBookPath)
    Assert-True ($sharedAttached['modules'].Count -eq $modules.Count) `
        'A shared-locked workbook lost modules.'
    Assert-True ($sharedAttached['warning'] -eq $false) `
        'A shared-locked workbook produced a read warning.'
} finally {
    $held.Dispose()
}

# An unreadable path still reports a clear attach error.
$missingAttachPath = Join-Path $testdataRoot (
    'host-missing-' + [Guid]::NewGuid().ToString('N') + '.xlsm')
Assert-InsideDirectory $missingAttachPath $testdataRoot
$lockErrorCode = ''
try {
    $service.AttachBook($missingAttachPath)
} catch [MacroStudio.MacroStudioException] {
    $lockErrorCode = $_.Exception.ErrorCode
}
Assert-True ($lockErrorCode -eq 'E-ATTACH-02') `
    "Missing workbook error mismatch: $lockErrorCode"

$tempBase = Join-Path $testdataRoot (
    'p3-host-' + [Guid]::NewGuid().ToString('N'))
$presetRoot = Join-Path $tempBase 'presets'
$templateRoot = Join-Path $tempBase 'templates'
$messageRoot = Join-Path $tempBase 'assets\messages'
Assert-InsideDirectory $tempBase $testdataRoot
[IO.Directory]::CreateDirectory($presetRoot) | Out-Null
[IO.Directory]::CreateDirectory($templateRoot) | Out-Null
[IO.Directory]::CreateDirectory($messageRoot) | Out-Null
[IO.File]::Copy(
    (Join-Path $repoRoot 'assets\messages\build-file-label.txt'),
    (Join-Path $messageRoot 'build-file-label.txt'))
[IO.File]::Copy(
    (Join-Path $repoRoot 'assets\messages\preset-encoding-error.txt'),
    (Join-Path $messageRoot 'preset-encoding-error.txt'))
[IO.File]::WriteAllText(
    (Join-Path $presetRoot 'b.md'),
    'second',
    (New-Object Text.UTF8Encoding($true)))
[IO.File]::WriteAllText(
    (Join-Path $presetRoot 'A.md'),
    'first',
    (New-Object Text.UTF8Encoding($true)))
$requestTemplatePath = Join-Path $templateRoot 'request-template.txt'
[IO.File]::WriteAllText(
    $requestTemplatePath,
    'first template',
    (New-Object Text.UTF8Encoding($false)))

try {
    $presetService = New-Object MacroStudio.HostServices($null, $tempBase)
    $presetInfo = $presetService.GetAppInfo()
    Assert-True ($presetInfo['presets'].Count -eq 2) `
        'Preset count mismatch.'
    Assert-True ($presetInfo['presets'][0]['file'] -eq 'A.md') `
        'Preset sort order mismatch.'
    # The host carries the markdown text; the UI parses it. No preset
    # name is computed here.
    Assert-True (
        -not $presetInfo['presets'][0].ContainsKey('name')) `
        'The host must not name presets.'
    Assert-True (
        $presetInfo['presets'][0]['content'] -ceq 'first' -and
        $presetInfo['presets'][1]['content'] -ceq 'second') `
        'GetAppInfo must return the markdown of every preset.'
    Assert-True (
        $presetService.ReadPreset('A.md')['content'] -eq 'first') `
        'Preset content mismatch.'

    # Discovery is dynamic: adding, removing and renaming files, or
    # editing one, changes the list with no code change and no restart.
    [IO.File]::WriteAllText(
        (Join-Path $presetRoot 'c.md'),
        'third',
        (New-Object Text.UTF8Encoding($true)))
    [IO.File]::WriteAllText(
        (Join-Path $presetRoot 'notes.txt'),
        'not a preset',
        (New-Object Text.UTF8Encoding($true)))
    $addedInfo = $presetService.GetAppInfo()
    Assert-True ($addedInfo['presets'].Count -eq 3) `
        'An added preset file was not discovered.'
    Assert-True (
        @($addedInfo['presets'] |
            ForEach-Object { $_['file'] }) -contains 'c.md') `
        'The added preset is missing from the list.'
    Assert-True (
        -not (@($addedInfo['presets'] |
            ForEach-Object { $_['file'] }) -contains 'notes.txt')) `
        'A non-markdown file must not become a preset.'

    [IO.File]::Move(
        (Join-Path $presetRoot 'c.md'),
        (Join-Path $presetRoot 'renamed.md'))
    [IO.File]::WriteAllText(
        (Join-Path $presetRoot 'b.md'),
        'edited',
        (New-Object Text.UTF8Encoding($true)))
    $renamedInfo = $presetService.GetAppInfo()
    $renamedFiles = @($renamedInfo['presets'] |
        ForEach-Object { $_['file'] })
    Assert-True (
        ($renamedFiles -contains 'renamed.md') -and
        -not ($renamedFiles -contains 'c.md')) `
        'A renamed preset file was not rediscovered.'
    Assert-True (
        @($renamedInfo['presets'] |
            Where-Object { $_['file'] -eq 'b.md' })[0]['content'] -ceq
        'edited') `
        'An edited preset was not read again.'

    [IO.File]::Delete((Join-Path $presetRoot 'renamed.md'))
    [IO.File]::Delete((Join-Path $presetRoot 'notes.txt'))
    Assert-True (
        $presetService.GetAppInfo()['presets'].Count -eq 2) `
        'A deleted preset file is still listed.'
    Assert-True (
        $presetService.ReadRequestTemplate()['content'] -ceq
        'first template') `
        'Initial request template content mismatch.'
    [IO.File]::WriteAllText(
        $requestTemplatePath,
        'second template',
        (New-Object Text.UTF8Encoding($false)))
    Assert-True (
        $presetService.ReadRequestTemplate()['content'] -ceq
        'second template') `
        'Request template was not read again after editing.'

    $presetErrorCode = ''
    try {
        $presetService.ReadPreset('..\outside.md')
    } catch [MacroStudio.HostActionException] {
        $presetErrorCode = $_.Exception.ErrorCode
    }
    Assert-True ($presetErrorCode -eq 'E-SYS-02') `
        "Preset traversal error mismatch: $presetErrorCode"

    $invalidPresetPath = Join-Path $presetRoot 'invalid-encoding.md'
    [IO.File]::WriteAllBytes(
        $invalidPresetPath,
        [byte[]](0x83, 0x76))
    $presetEncodingErrorCode = ''
    $presetEncodingMessage = ''
    $presetEncodingUserMessage = ''
    try {
        $presetService.ReadPreset('invalid-encoding.md')
    } catch [MacroStudio.HostActionException] {
        $presetEncodingErrorCode = $_.Exception.ErrorCode
        $presetEncodingMessage = $_.Exception.Message
        $presetEncodingUserMessage =
            $_.Exception.ErrorData['userMessage']
    }
    $expectedEncodingMessage = [IO.File]::ReadAllText(
        (Join-Path $messageRoot 'preset-encoding-error.txt'),
        [Text.Encoding]::UTF8).Trim()
    Assert-True ($presetEncodingErrorCode -eq 'E-SYS-02') `
        "Preset encoding error mismatch: $presetEncodingErrorCode"
    Assert-True ($presetEncodingMessage -eq $expectedEncodingMessage) `
        'Preset encoding exception message mismatch.'
    Assert-True (
        $presetEncodingUserMessage -eq $expectedEncodingMessage) `
        'Preset encoding user message mismatch.'

    # A file the host cannot decode stays visible in the list, marked
    # as unreadable, so the mistake is not silently hidden.
    $encodingEntry = @($presetService.GetAppInfo()['presets'] |
        Where-Object { $_['file'] -eq 'invalid-encoding.md' })
    Assert-True ($encodingEntry.Count -eq 1) `
        'An unreadable preset disappeared from the list.'
    Assert-True (
        $encodingEntry[0]['error'] -eq 'read' -and
        $encodingEntry[0]['content'] -eq '') `
        'An unreadable preset must be reported with an error flag.'
    [IO.File]::Delete($invalidPresetPath)

    [IO.File]::Delete($requestTemplatePath)
    $missingTemplateErrorCode = ''
    try {
        $presetService.ReadRequestTemplate()
    } catch [MacroStudio.HostActionException] {
        $missingTemplateErrorCode = $_.Exception.ErrorCode
    }
    Assert-True ($missingTemplateErrorCode -eq 'E-GEN-02') `
        "Missing template error mismatch: $missingTemplateErrorCode"

    [IO.File]::WriteAllBytes(
        $requestTemplatePath,
        [byte[]](0x83, 0x76))
    $templateEncodingErrorCode = ''
    try {
        $presetService.ReadRequestTemplate()
    } catch [MacroStudio.HostActionException] {
        $templateEncodingErrorCode = $_.Exception.ErrorCode
    }
    Assert-True ($templateEncodingErrorCode -eq 'E-GEN-02') `
        "Template encoding error mismatch: $templateEncodingErrorCode"
} finally {
    Assert-InsideDirectory $tempBase $testdataRoot
    if ([IO.Directory]::Exists($tempBase)) {
        [IO.Directory]::Delete($tempBase, $true)
    }
}

$identityChanges = New-Object `
    'System.Collections.Generic.Dictionary[string,string]' `
    ([StringComparer]::OrdinalIgnoreCase)
$identityChanges.Add(
    'AppController',
    $modules[2]['attributes'] + $modules[2]['code'])

$successOutput = ''
try {
    $buildTimestamp = [DateTime]::Now.ToString('yyyyMMdd_HHmmss')
    $build = $service.BuildBook($identityChanges, $buildTimestamp)
    $successOutput = $build['outputPath']
    Assert-InsideDirectory $successOutput $testdataRoot
    Assert-True ([IO.File]::Exists($successOutput)) `
        'Host build output was not created.'
    Assert-True ($build['results'].Count -eq 1) `
        'Host build result count mismatch.'
    Assert-True (
        $build['results'][0]['result'] -eq 'skipped_no_change') `
        'Host identity build result mismatch.'
    $runFolder = [IO.Path]::GetDirectoryName($successOutput)
    Assert-True (
        [IO.Path]::GetFileName($runFolder) -ceq
        ('test_large_' + $buildTimestamp)) `
        'Host build did not use the run folder for this timestamp.'
    Assert-True (
        [IO.Path]::GetFileName(
            [IO.Path]::GetDirectoryName($runFolder)) -ceq 'MacroStudio') `
        'The run folder must sit under a MacroStudio folder.'
    Assert-True (
        [IO.Path]::GetFileName($successOutput) -ceq
        'test_large_macrostudio.xlsm') `
        'Host build output name mismatch.'
} finally {
    if (-not [string]::IsNullOrEmpty($successOutput)) {
        Assert-InsideDirectory $successOutput $testdataRoot
        if ([IO.File]::Exists($successOutput)) {
            [IO.File]::Delete($successOutput)
        }
    }
}

$diffLabel = [IO.File]::ReadAllText(
    (Join-Path $repoRoot 'assets\messages\diff-file-label.txt'),
    [Text.Encoding]::UTF8).Trim()
$diffHtml = (
    '<!doctype html><html lang="ja"><head>' +
    '<meta charset="utf-8"><style>body{color:#fff}</style>' +
    '</head><body><h1>diff</h1></body></html>')
$noAdditions = New-Object `
    'System.Collections.Generic.List[MacroStudio.VbaModuleAddition]'
$diffBuildOutput = ''
$diffPath = ''
try {
    $diffTimestamp = [DateTime]::Now.AddSeconds(
        2).ToString('yyyyMMdd_HHmmss')
    $diffBuild = $service.BuildBook(
        $identityChanges,
        $noAdditions,
        $diffTimestamp,
        $diffHtml)
    $diffBuildOutput = $diffBuild['outputPath']
    $diffPath = $diffBuild['diffPath']
    Assert-InsideDirectory $diffBuildOutput $testdataRoot
    Assert-InsideDirectory $diffPath $testdataRoot
    Assert-True ([IO.File]::Exists($diffBuildOutput)) `
        'Diff-report build output was not created.'
    Assert-True ([IO.File]::Exists($diffPath)) `
        'Diff report was not created.'
    Assert-True (
        [IO.Path]::GetFileName($diffPath) -ceq 'diff-report.html') `
        'Diff report file name mismatch.'
    Assert-True (
        [IO.Path]::GetDirectoryName($diffPath) -ceq
        [IO.Path]::GetDirectoryName($diffBuildOutput)) `
        'The diff report must sit beside the built workbook.'
    $diffBytes = [IO.File]::ReadAllBytes($diffPath)
    Assert-True (
        $diffBytes.Length -ge 3 -and
        $diffBytes[0] -eq 0xEF -and
        $diffBytes[1] -eq 0xBB -and
        $diffBytes[2] -eq 0xBF) `
        'Diff report does not have a UTF-8 BOM.'
    Assert-True (
        [IO.File]::ReadAllText(
            $diffPath,
            [Text.Encoding]::UTF8) -ceq
        $diffHtml) `
        'Diff report content mismatch.'
    Assert-True (-not $diffBuild.ContainsKey('diffError')) `
        'Successful diff output reported an error.'
} finally {
    foreach ($path in @($diffBuildOutput, $diffPath)) {
        if (-not [string]::IsNullOrEmpty($path)) {
            Assert-InsideDirectory $path $testdataRoot
            if ([IO.File]::Exists($path)) {
                [IO.File]::Delete($path)
            }
        }
    }
}

$collisionOutput = ''
$collisionPath = ''
try {
    $collisionTimestamp = [DateTime]::Now.AddSeconds(
        4).ToString('yyyyMMdd_HHmmss')
    $collisionFolder = Join-Path $testdataRoot (
        'MacroStudio\test_large_' + $collisionTimestamp)
    [IO.Directory]::CreateDirectory($collisionFolder) | Out-Null
    $collisionPath = Join-Path $collisionFolder 'diff-report.html'
    [IO.File]::WriteAllText(
        $collisionPath,
        'existing report',
        (New-Object Text.UTF8Encoding($false)))
    $collisionService = New-Object MacroStudio.HostServices($null, $repoRoot)
    [void]$collisionService.AttachBook($resolvedBookPath)
    $collisionBuild = $collisionService.BuildBook(
        $identityChanges,
        $noAdditions,
        $collisionTimestamp,
        $diffHtml)
    $collisionOutput = $collisionBuild['outputPath']
    Assert-InsideDirectory $collisionOutput $testdataRoot
    Assert-True ([IO.File]::Exists($collisionOutput)) `
        'A diff-report failure cancelled the workbook build.'
    Assert-True (
        -not [string]::IsNullOrEmpty(
            $collisionBuild['diffError'])) `
        'A diff-report failure was not returned.'
    Assert-True (-not $collisionBuild.ContainsKey('diffPath')) `
        'A failed diff report returned a path.'
    Assert-True (
        [IO.File]::ReadAllText(
            $collisionPath,
            [Text.Encoding]::UTF8) -ceq
        'existing report') `
        'A pre-existing diff report was overwritten or removed.'
} finally {
    foreach ($path in @($collisionOutput, $collisionPath)) {
        if (-not [string]::IsNullOrEmpty($path)) {
            Assert-InsideDirectory $path $testdataRoot
            if ([IO.File]::Exists($path)) {
                [IO.File]::Delete($path)
            }
        }
    }
}

$invalidChanges = New-Object `
    'System.Collections.Generic.Dictionary[string,string]' `
    ([StringComparer]::OrdinalIgnoreCase)
$invalidChanges.Add('MissingModule', 'Option Explicit' + "`r`n")
$buildErrorCode = ''
$buildErrorData = $null
try {
    $service.BuildBook(
        $invalidChanges,
        [DateTime]::Now.ToString('yyyyMMdd_HHmmss'))
} catch [MacroStudio.HostActionException] {
    $buildErrorCode = $_.Exception.ErrorCode
    $buildErrorData = $_.Exception.ErrorData
}
Assert-True ($buildErrorCode -eq 'E-BUILD-01') `
    "Host build error mismatch: $buildErrorCode"
Assert-True ($null -ne $buildErrorData) `
    'Host build error data was not preserved.'
Assert-True ($null -ne $buildErrorData['results']) `
    'Host build error results were not preserved.'

$timestampErrorCode = ''
try {
    $service.BuildBook($identityChanges, '20260230_010203')
} catch [MacroStudio.HostActionException] {
    $timestampErrorCode = $_.Exception.ErrorCode
}
Assert-True ($timestampErrorCode -eq 'E-BUILD-01') `
    "Host build timestamp error mismatch: $timestampErrorCode"

# Audit 2026-07-30, P2-2 and P1-2.
#
# P2-2: building again after a success is a documented way through the
# flow, and the run folder is fixed when the request is written. So this
# run's own workbook, diff report and summary note are replaced as one
# generation, while a file of the same name that this run did not write
# is never touched.
#
# P1-2: the answer was written against the VBA as it stood when the
# request was prepared. If the workbook was edited and saved in the
# meantime, writing that answer would silently drop the edit, so the
# build refuses instead of producing an output.
$signatureBase = Join-Path $testdataRoot (
    'host-signature-' + [Guid]::NewGuid().ToString('N'))
Assert-InsideDirectory $signatureBase $testdataRoot
[IO.Directory]::CreateDirectory($signatureBase) | Out-Null
try {
    $signatureBook = Join-Path $signatureBase 'signature.xlsm'
    [IO.File]::Copy($resolvedBookPath, $signatureBook)

    $signatureService = New-Object MacroStudio.HostServices($null, $repoRoot)
    $signatureModules = @(
        $signatureService.AttachBook($signatureBook)['modules'])
    $signatureChanges = New-Object `
        'System.Collections.Generic.Dictionary[string,string]' `
        ([StringComparer]::OrdinalIgnoreCase)
    $signatureChanges.Add(
        $signatureModules[2]['name'],
        $signatureModules[2]['attributes'] +
            $signatureModules[2]['code'])
    $signatureStamp = [DateTime]::Now.AddSeconds(
        6).ToString('yyyyMMdd_HHmmss')
    $signatureName = 'signature_macrostudio.xlsm'

    $firstBuild = $signatureService.BuildBook(
        $signatureChanges,
        $noAdditions,
        $signatureStamp,
        '<!doctype html><html><body>first</body></html>',
        $signatureName,
        "first note`r`n")
    $signatureOutput = $firstBuild['outputPath']
    $signatureFolder = [IO.Path]::GetDirectoryName($signatureOutput)
    Assert-InsideDirectory $signatureOutput $signatureBase
    Assert-True ([IO.File]::Exists($signatureOutput)) `
        'The first build of the attached workbook must succeed.'
    Assert-True (
        [IO.File]::ReadAllText(
            (Join-Path $signatureFolder 'result.md'),
            [Text.Encoding]::UTF8) -ceq "first note`r`n") `
        'The first summary note was not written.'

    # The same run builds again with the default output name. Before the
    # fix this failed outright, and a renamed output left the report and
    # the note behind from the earlier generation.
    $rebuild = $signatureService.BuildBook(
        $signatureChanges,
        $noAdditions,
        $signatureStamp,
        '<!doctype html><html><body>second</body></html>',
        $signatureName,
        "second note`r`n")
    Assert-True ($rebuild['outputPath'] -ceq $signatureOutput) `
        'The rebuild must keep the output name of the same run.'
    Assert-True ([IO.File]::Exists($signatureOutput)) `
        'The rebuild must leave a workbook behind.'
    Assert-True (-not $rebuild.ContainsKey('diffError')) `
        'The rebuild could not replace its own diff report.'
    Assert-True (-not $rebuild.ContainsKey('resultError')) `
        'The rebuild could not replace its own summary note.'
    Assert-True (
        [IO.File]::ReadAllText(
            $rebuild['diffPath'],
            [Text.Encoding]::UTF8).Contains('second')) `
        'The diff report is still the one from the earlier build.'
    Assert-True (
        [IO.File]::ReadAllText(
            $rebuild['resultPath'],
            [Text.Encoding]::UTF8) -ceq "second note`r`n") `
        'The summary note is still the one from the earlier build.'
    Assert-True (
        @([IO.Directory]::GetFiles(
            $signatureFolder, '*.rebuild')).Count -eq 0 -and
        @([IO.Directory]::GetFiles(
            $signatureFolder, '*.previous')).Count -eq 0) `
        'The rebuild left its workpiece or the old generation behind.'

    # A workbook of the same name that this run did not write stays put.
    $foreignService = New-Object MacroStudio.HostServices($null, $repoRoot)
    [void]$foreignService.AttachBook($signatureBook)
    $foreignPath = Join-Path $signatureFolder 'foreign.xlsm'
    [IO.File]::WriteAllText(
        $foreignPath,
        'not ours',
        (New-Object Text.UTF8Encoding($false)))
    $foreignCode = ''
    try {
        $foreignService.BuildBook(
            $signatureChanges,
            $noAdditions,
            $signatureStamp,
            $diffHtml,
            'foreign.xlsm',
            "note`r`n")
    } catch [MacroStudio.HostActionException] {
        $foreignCode = $_.Exception.ErrorCode
    }
    Assert-True ($foreignCode -eq 'E-BUILD-03') `
        "A foreign output file must not be replaced: $foreignCode"
    Assert-True (
        [IO.File]::ReadAllText(
            $foreignPath,
            [Text.Encoding]::UTF8) -ceq 'not ours') `
        'A file this run did not write was overwritten.'

    # The workbook is edited and saved after the request was prepared.
    $editedPath = Join-Path $signatureBase 'edited.xlsm'
    $editedChanges = New-Object `
        'System.Collections.Generic.Dictionary[string,string]' `
        ([StringComparer]::OrdinalIgnoreCase)
    $editedChanges.Add(
        $signatureModules[2]['name'],
        $signatureModules[2]['attributes'] +
            $signatureModules[2]['code'] +
            "' edited in Excel`r`n")
    $editedBuild = [MacroStudio.BookIO]::BuildCopy(
        $signatureBook,
        $editedPath,
        $editedChanges,
        $noAdditions)
    Assert-True $editedBuild.Success `
        ('Could not produce an edited workbook: ' + $editedBuild.Message)
    [IO.File]::Copy($editedPath, $signatureBook, $true)

    $staleCode = ''
    try {
        $signatureService.BuildBook(
            $signatureChanges,
            $noAdditions,
            $signatureStamp,
            $diffHtml,
            $signatureName,
            "stale note`r`n")
    } catch [MacroStudio.HostActionException] {
        $staleCode = $_.Exception.ErrorCode
    }
    Assert-True ($staleCode -eq 'E-BUILD-04') `
        ('A workbook edited after the request must refuse the build: ' +
            $staleCode)
    Assert-True (
        [IO.File]::ReadAllText(
            $rebuild['resultPath'],
            [Text.Encoding]::UTF8) -ceq "second note`r`n") `
        'A refused build replaced the earlier generation anyway.'
    Assert-True (
        @([IO.Directory]::GetFiles(
            $signatureFolder, '*.rebuild')).Count -eq 0 -and
        @([IO.Directory]::GetFiles(
            $signatureFolder, '*.previous')).Count -eq 0) `
        'A refused build left a workpiece or an aside copy behind.'
    Assert-True (
        [IO.File]::Exists((Join-Path $signatureFolder $signatureName))) `
        'A refused build removed the workbook the earlier build made.'

    # The signature is what the attach step read, so attaching the edited
    # workbook makes it buildable again.
    $freshService = New-Object MacroStudio.HostServices($null, $repoRoot)
    $freshModules = @(
        $freshService.AttachBook($signatureBook)['modules'])
    $freshChanges = New-Object `
        'System.Collections.Generic.Dictionary[string,string]' `
        ([StringComparer]::OrdinalIgnoreCase)
    $freshChanges.Add(
        $freshModules[2]['name'],
        $freshModules[2]['attributes'] + $freshModules[2]['code'])
    $freshBuild = $freshService.BuildBook(
        $freshChanges,
        $noAdditions,
        [DateTime]::Now.AddSeconds(8).ToString('yyyyMMdd_HHmmss'),
        $diffHtml,
        'fresh_macrostudio.xlsm',
        "fresh note`r`n")
    Assert-True ([IO.File]::Exists($freshBuild['outputPath'])) `
        'Re-attaching the edited workbook must make it buildable again.'
    Assert-True (
        $freshModules[2]['code'].Contains('edited in Excel')) `
        'The re-attached workbook must carry the edit.'
} finally {
    Assert-InsideDirectory $signatureBase $testdataRoot
    if ([IO.Directory]::Exists($signatureBase)) {
        [IO.Directory]::Delete($signatureBase, $true)
    }
}

$clipboardService = New-Object MacroStudio.HostServices($null, $repoRoot)
$originalClipboard = $clipboardService.ReadClipboard()['text']
try {
    $clipboardProbe = "MacroStudio clipboard probe`r`n2 lines`r`n"
    [void]$clipboardService.WriteClipboard($clipboardProbe)
    $clipboardRead = $clipboardService.ReadClipboard()['text']
    Assert-True ($clipboardRead -ceq $clipboardProbe) `
        'Clipboard round trip mismatch.'
    $clipboardNullCode = ''
    try {
        [void]$clipboardService.WriteClipboard([NullString]::Value)
    } catch [MacroStudio.HostActionException] {
        $clipboardNullCode = $_.Exception.ErrorCode
    }
    Assert-True ($clipboardNullCode -eq 'E-GEN-03') `
        "Clipboard null error mismatch: $clipboardNullCode"
} finally {
    [void]$clipboardService.WriteClipboard([string]$originalClipboard)
}

if ($TestExplorer) {
    $requestBookPath = Join-Path (
        Join-Path $testdataRoot 't2_6_outputs') 'identity.xlsm'
    Assert-True (Test-Path -LiteralPath $requestBookPath -PathType Leaf) `
        "Request test workbook was not found: $requestBookPath"

    $requestService = New-Object MacroStudio.HostServices($null, $repoRoot)
    [void]$requestService.AttachBook($requestBookPath)
    $requestBody = "request body`r`n"
    $codeBody = "code body`r`n"
    $runFolder = ''
    try {
        $stamp = [DateTime]::Now.ToString('yyyyMMdd_HHmmss')
        $written = $requestService.WriteRequestFiles(
            $stamp,
            $requestBody,
            $codeBody)
        $runFolder = $written['folderPath']
        Assert-InsideDirectory $runFolder (
            Join-Path $testdataRoot 't2_6_outputs')
        Assert-True (
            [IO.Path]::GetFileName($runFolder) -ceq
            ([IO.Path]::GetFileNameWithoutExtension($requestBookPath) +
                '_' + $stamp)) `
            'The run folder name must be the book name plus the stamp.'
        Assert-True (
            [IO.Path]::GetFileName(
                [IO.Path]::GetDirectoryName($runFolder)) -ceq
            'MacroStudio') `
            'The run folder must sit under a MacroStudio folder.'
        Assert-True (
            [IO.Path]::GetFileName($written['requestPath']) -ceq
            'request.md' -and
            [IO.Path]::GetFileName($written['codePath']) -ceq
            'source-code.md') `
            'The request files must be request.md and source-code.md.'

        foreach ($pair in @(
            @($written['requestPath'], $requestBody),
            @($written['codePath'], $codeBody))) {
            Assert-True ([IO.File]::Exists($pair[0])) `
                ('Request file was not created: ' + $pair[0])
            $bytes = [IO.File]::ReadAllBytes($pair[0])
            Assert-True (
                $bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and
                $bytes[1] -eq 0xBB -and
                $bytes[2] -eq 0xBF) `
                ('Request file has no UTF-8 BOM: ' + $pair[0])
            Assert-True (
                [IO.File]::ReadAllText(
                    $pair[0],
                    [Text.Encoding]::UTF8) -ceq $pair[1]) `
                ('Request file content mismatch: ' + $pair[0])
        }

        # The build of the same run reuses the folder created here.
        $sameRunChanges = New-Object `
            'System.Collections.Generic.Dictionary[string,string]' `
            ([StringComparer]::OrdinalIgnoreCase)
        $sameRunModules = @($requestService.AttachBook(
            $requestBookPath)['modules'])
        $requestService.WriteRequestFiles(
            $stamp,
            $requestBody,
            $codeBody) | Out-Null
        $sameRunChanges.Add(
            $sameRunModules[0]['name'],
            $sameRunModules[0]['attributes'] +
                $sameRunModules[0]['code'])
        $noAdds = New-Object `
            'System.Collections.Generic.List[MacroStudio.VbaModuleAddition]'
        $sameRunBuild = $requestService.BuildBook(
            $sameRunChanges,
            $noAdds,
            $stamp,
            '<!doctype html><html><body>d</body></html>',
            'renamed_output.xlsm')
        Assert-True (
            [IO.Path]::GetDirectoryName(
                $sameRunBuild['outputPath']) -ceq $runFolder) `
            'The build must stay in the run folder of this request.'
        Assert-True (
            [IO.Path]::GetFileName(
                $sameRunBuild['outputPath']) -ceq
            'renamed_output.xlsm') `
            'The build must use the name given by the screen.'
        Assert-True (
            [IO.File]::Exists(
                (Join-Path $runFolder 'diff-report.html'))) `
            'The diff report must join the same folder.'

        $nameErrorCode = ''
        try {
            $requestService.BuildBook(
                $sameRunChanges,
                $noAdds,
                $stamp,
                '<!doctype html><html><body>d</body></html>',
                '..\escaped.xlsm')
        } catch [MacroStudio.HostActionException] {
            $nameErrorCode = $_.Exception.ErrorCode
        }
        Assert-True ($nameErrorCode -eq 'E-BUILD-03') `
            "An unusable output name must be refused: $nameErrorCode"

        $extensionErrorCode = ''
        try {
            $requestService.BuildBook(
                $sameRunChanges,
                $noAdds,
                $stamp,
                '<!doctype html><html><body>d</body></html>',
                'wrong_kind.txt')
        } catch [MacroStudio.HostActionException] {
            $extensionErrorCode = $_.Exception.ErrorCode
        }
        Assert-True ($extensionErrorCode -eq 'E-BUILD-03') `
            "A different extension must be refused: $extensionErrorCode"
    } finally {
        if (-not [string]::IsNullOrEmpty($runFolder)) {
            Assert-InsideDirectory $runFolder (
                Join-Path $testdataRoot 't2_6_outputs')
            if ([IO.Directory]::Exists($runFolder)) {
                [IO.Directory]::Delete($runFolder, $true)
            }
            $macroRoot = [IO.Path]::GetDirectoryName($runFolder)
            if ([IO.Directory]::Exists($macroRoot) -and
                @([IO.Directory]::GetFileSystemEntries(
                    $macroRoot)).Count -eq 0) {
                [IO.Directory]::Delete($macroRoot)
            }
        }
    }
}

Write-Output 'test-hostservices: PASS'
Write-Output (
    'version={0}, modules={1}, totalLines={2}, lock=E-ATTACH-02, explorer={3}' -f `
    $appInfo['version'],
    $modules.Count,
    $book['totalLines'],
    $(if ($TestExplorer) { 'run-folder' } else { 'not-run' }))
