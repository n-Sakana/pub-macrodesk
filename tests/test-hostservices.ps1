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
$service = New-Object MacroDesk.HostServices($null, $repoRoot)

$appInfo = $service.GetAppInfo()
Assert-True ($appInfo['version'] -eq '1.0') `
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
} catch [MacroDesk.MacroDeskException] {
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
    $presetService = New-Object MacroDesk.HostServices($null, $tempBase)
    $presetInfo = $presetService.GetAppInfo()
    Assert-True ($presetInfo['presets'].Count -eq 2) `
        'Preset count mismatch.'
    Assert-True ($presetInfo['presets'][0]['file'] -eq 'A.md') `
        'Preset sort order mismatch.'
    Assert-True (
        $presetService.ReadPreset('A.md')['content'] -eq 'first') `
        'Preset content mismatch.'
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
    } catch [MacroDesk.HostActionException] {
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
    } catch [MacroDesk.HostActionException] {
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

    [IO.File]::Delete($requestTemplatePath)
    $missingTemplateErrorCode = ''
    try {
        $presetService.ReadRequestTemplate()
    } catch [MacroDesk.HostActionException] {
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
    } catch [MacroDesk.HostActionException] {
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
    Assert-True (
        [IO.Path]::GetFileNameWithoutExtension($successOutput).EndsWith(
            $buildTimestamp,
            [StringComparison]::Ordinal)) `
        'Host build did not use the requested output timestamp.'
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
    'System.Collections.Generic.List[MacroDesk.VbaModuleAddition]'
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
        [IO.Path]::GetFileName($diffPath) -ceq
        (
            'test_large_' +
            $diffLabel +
            '_' +
            $diffTimestamp +
            '.html')) `
        'Diff report file name mismatch.'
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
    $collisionPath = Join-Path $testdataRoot (
        'test_large_' +
        $diffLabel +
        '_' +
        $collisionTimestamp +
        '.html')
    [IO.File]::WriteAllText(
        $collisionPath,
        'existing report',
        (New-Object Text.UTF8Encoding($false)))
    $collisionBuild = $service.BuildBook(
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
} catch [MacroDesk.HostActionException] {
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
} catch [MacroDesk.HostActionException] {
    $timestampErrorCode = $_.Exception.ErrorCode
}
Assert-True ($timestampErrorCode -eq 'E-BUILD-01') `
    "Host build timestamp error mismatch: $timestampErrorCode"

$clipboardService = New-Object MacroDesk.HostServices($null, $repoRoot)
$originalClipboard = $clipboardService.ReadClipboard()['text']
try {
    $clipboardProbe = "MacroDesk clipboard probe`r`n2 lines`r`n"
    [void]$clipboardService.WriteClipboard($clipboardProbe)
    $clipboardRead = $clipboardService.ReadClipboard()['text']
    Assert-True ($clipboardRead -ceq $clipboardProbe) `
        'Clipboard round trip mismatch.'
    $clipboardNullCode = ''
    try {
        [void]$clipboardService.WriteClipboard([NullString]::Value)
    } catch [MacroDesk.HostActionException] {
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

    $shell = New-Object -ComObject Shell.Application
    $beforeWindows = @($shell.Windows())
    $beforeHandles = @{}
    foreach ($shellWindow in $beforeWindows) {
        $beforeHandles[[string]$shellWindow.HWND] = $true
    }

    $requestService = New-Object MacroDesk.HostServices($null, $repoRoot)
    [void]$requestService.AttachBook($requestBookPath)
    $requestContent = "first line`r`nsecond line`r`n"
    $requestPath = ''
    try {
        $requestResult = $requestService.WriteCodeFile(
            $requestContent)
        $requestPath = $requestResult['path']
        Assert-InsideDirectory $requestPath (
            Join-Path $testdataRoot 't2_6_outputs')
        Assert-True ([IO.File]::Exists($requestPath)) `
            'Code file was not created.'
        $codeFileLabel = [IO.File]::ReadAllText(
            (Join-Path $repoRoot 'assets\messages\code-file-label.txt'),
            [Text.Encoding]::UTF8).Trim()
        Assert-True (
            [IO.Path]::GetFileName($requestPath) -like
                ('*_' + $codeFileLabel + '_*.txt')) `
            'Code file name must use the code-file label.'

        $bytes = [IO.File]::ReadAllBytes($requestPath)
        Assert-True (
            $bytes.Length -ge 3 -and
            $bytes[0] -eq 0xEF -and
            $bytes[1] -eq 0xBB -and
            $bytes[2] -eq 0xBF) `
            'Request file does not have a UTF-8 BOM.'
        $requestText = [IO.File]::ReadAllText(
            $requestPath,
            [Text.Encoding]::UTF8)
        Assert-True ($requestText -ceq $requestContent) `
            'Request file content mismatch.'

        $selected = $false
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
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
            'Explorer did not select the request file.'
    } finally {
        if (-not [string]::IsNullOrEmpty($requestPath)) {
            Assert-InsideDirectory $requestPath (
                Join-Path $testdataRoot 't2_6_outputs')
            if ([IO.File]::Exists($requestPath)) {
                [IO.File]::Delete($requestPath)
            }
        }

        foreach ($shellWindow in @($shell.Windows())) {
            if (-not $beforeHandles.ContainsKey(
                [string]$shellWindow.HWND)) {
                try {
                    $shellWindow.Quit()
                } catch {
                }
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
    $(if ($TestExplorer) { 'selected' } else { 'not-run' }))
