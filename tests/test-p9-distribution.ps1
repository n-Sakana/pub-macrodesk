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

function Read-SharedText {
    param([string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        return ''
    }

    $stream = New-Object IO.FileStream(
        $Path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::ReadWrite)
    try {
        $reader = New-Object IO.StreamReader(
            $stream,
            [Text.Encoding]::UTF8,
            $true)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Invoke-WindowsPowerShell {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$Label
    )

    $oldErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Executable @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw (
            $Label + " failed with exit code " +
            $exitCode + ":`n" +
            ($output -join "`n"))
    }
    return $output
}

function Get-StagedPowerShell {
    param(
        [hashtable]$Baseline,
        [string]$ScriptPath
    )

    $items = @(Get-CimInstance Win32_Process -Filter `
        "Name = 'powershell.exe'" | Where-Object {
            -not $Baseline.ContainsKey([int]$_.ProcessId) -and
            -not [string]::IsNullOrEmpty($_.CommandLine) -and
            $_.CommandLine.IndexOf(
                $ScriptPath,
                [StringComparison]::OrdinalIgnoreCase) -ge 0
        } | Sort-Object -Property CreationDate)
    if ($items.Count -eq 0) {
        return $null
    }
    return $items[$items.Count - 1]
}

function Stop-StagedApplication {
    param(
        [int]$ProcessId,
        [string]$StageRoot
    )

    if ($ProcessId -le 0) {
        return
    }

    $info = Get-CimInstance Win32_Process -Filter (
        'ProcessId = ' + $ProcessId) -ErrorAction SilentlyContinue
    if ($null -eq $info) {
        return
    }
    Assert-True (
        -not [string]::IsNullOrEmpty($info.CommandLine) -and
        $info.CommandLine.IndexOf(
            $StageRoot,
            [StringComparison]::OrdinalIgnoreCase) -ge 0) `
        "Refusing to stop a process outside the P9 stage: $ProcessId"

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return
    }
    [void]$process.CloseMainWindow()
    if (-not $process.WaitForExit(15000)) {
        $info = Get-CimInstance Win32_Process -Filter (
            'ProcessId = ' + $ProcessId) -ErrorAction SilentlyContinue
        Assert-True (
            $null -ne $info -and
            $info.CommandLine.IndexOf(
                $StageRoot,
                [StringComparison]::OrdinalIgnoreCase) -ge 0) `
            "P9 process identity changed before cleanup: $ProcessId"
        Stop-Process -Id $ProcessId -Force
        [void]$process.WaitForExit(5000)
    }
}

$repoRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..')).Path
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$stageContainer = Join-Path $testdataRoot (
    'p9-smoke-' + [Guid]::NewGuid().ToString('N'))
$stageRoot = Join-Path $stageContainer 'distribution'
$smokeBook = Join-Path $testdataRoot 'test_large.xlsm'
$stagedScript = Join-Path $stageRoot 'macrodesk.ps1'
$launchPath = Join-Path $stageRoot 'launch.vbs'
$stagedProcessId = 0
$launcher = $null

Assert-InsideDirectory $stageContainer $testdataRoot
Assert-True (
    -not [IO.Directory]::Exists($stageContainer)) `
    "P9 stage already exists: $stageContainer"

try {
    [IO.Directory]::CreateDirectory($stageRoot) | Out-Null

    $excludedNames = @{
        '.git' = $true
        'testdata' = $true
    }
    foreach ($item in Get-ChildItem -LiteralPath $repoRoot -Force) {
        if ($excludedNames.ContainsKey($item.Name)) {
            continue
        }
        Copy-Item -LiteralPath $item.FullName `
            -Destination $stageRoot -Recurse -Force
    }
    Assert-True (
        -not [string]::Equals(
            $stageRoot,
            $repoRoot,
            [StringComparison]::OrdinalIgnoreCase)) `
        'The P9 product was not copied to an alternate base path.'
    foreach ($requiredPath in @(
        $launchPath,
        $stagedScript,
        (Join-Path $stageRoot 'assets\index.html'),
        (Join-Path $stageRoot 'src\01_App.cs'),
        (Join-Path $stageRoot `
            'lib\Microsoft.Web.WebView2.Wpf.dll'))) {
        Assert-True ([IO.File]::Exists($requiredPath)) `
            "Staged distribution file is missing: $requiredPath"
    }

    $runtimeTextFiles = @(
        Get-ChildItem -LiteralPath (
            Join-Path $stageRoot 'src') -Filter '*.cs' -File
        Get-ChildItem -LiteralPath (
            Join-Path $stageRoot 'assets') -Recurse -File
        Get-Item -LiteralPath $launchPath
        Get-Item -LiteralPath $stagedScript
        Get-Item -LiteralPath (Join-Path $stageRoot 'launch.bat')
    )
    foreach ($file in $runtimeTextFiles) {
        $text = [IO.File]::ReadAllText(
            $file.FullName,
            [Text.Encoding]::UTF8)
        Assert-True (
            $text.IndexOf(
                $repoRoot,
                [StringComparison]::OrdinalIgnoreCase) -lt 0) `
            "Original repository path is baked into: $($file.FullName)"
    }

    $readme = [IO.File]::ReadAllText(
        (Join-Path $stageRoot 'README.md'),
        [Text.Encoding]::UTF8)
    foreach ($requiredText in @(
        'launch.vbs',
        'WebView2',
        '%LOCALAPPDATA%\MacroDesk\logs\',
        '.xlsm',
        '.xlam',
        '.xlsb')) {
        Assert-True (
            $readme.IndexOf(
                $requiredText,
                [StringComparison]::OrdinalIgnoreCase) -ge 0) `
            "README runtime guidance is missing: $requiredText"
    }

    $windowsPowerShell = (Get-Command powershell.exe).Source
    $presetProbePath = Join-Path $PSScriptRoot `
        'test-p9-preset.ps1'
    $probeArguments = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $presetProbePath,
        '-ProductRoot',
        $stageRoot,
        '-BookPath',
        $smokeBook
    )
    $initialProbeOutput = Invoke-WindowsPowerShell `
        -Executable $windowsPowerShell `
        -Arguments $probeArguments `
        -Label 'Initial staged preset probe'
    $initialJson = @($initialProbeOutput | Where-Object {
        ([string]$_).TrimStart().StartsWith('{')
    } | Select-Object -Last 1)
    Assert-True ($initialJson.Count -eq 1) `
        'Initial staged preset probe returned no JSON.'
    $initialPresets = [string]$initialJson[0] | ConvertFrom-Json
    $diskPresetCount = @(
        Get-ChildItem -LiteralPath (
            Join-Path $stageRoot 'presets') -Filter '*.md' -File
    ).Count
    Assert-True (
        $initialPresets.count -eq $diskPresetCount) `
        'Initial preset button count does not match staged files.'

    $launchText = [IO.File]::ReadAllText(
        $launchPath,
        [Text.Encoding]::ASCII)
    Assert-True (
        $launchText -match
        '(?i)shell\.Run\s+command\s*,\s*0\s*,\s*False') `
        'launch.vbs does not request a hidden launcher window.'

    $baseline = @{}
    foreach ($item in Get-CimInstance Win32_Process) {
        $baseline[[int]$item.ProcessId] = $true
    }

    $logPath = Join-Path (
        [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::LocalApplicationData)) (
        'MacroDesk\logs\macrodesk_' +
        [DateTime]::Now.ToString('yyyyMMdd') +
        '.log')
    $logBefore = Read-SharedText $logPath

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = Join-Path $env:SystemRoot `
        'System32\wscript.exe'
    $startInfo.Arguments = '"' + $launchPath + '"'
    $startInfo.WorkingDirectory = $testdataRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $launcher = [Diagnostics.Process]::Start($startInfo)
    Assert-True ($null -ne $launcher) `
        'wscript.exe did not start launch.vbs.'

    $stagedProcessInfo = $null
    $stagedProcess = $null
    $launchDeadline = [DateTime]::UtcNow.AddSeconds(75)
    while ([DateTime]::UtcNow -lt $launchDeadline) {
        $stagedProcessInfo = Get-StagedPowerShell `
            -Baseline $baseline `
            -ScriptPath $stagedScript
        if ($null -ne $stagedProcessInfo) {
            $stagedProcessId = [int]$stagedProcessInfo.ProcessId
            $stagedProcess = Get-Process -Id $stagedProcessId `
                -ErrorAction SilentlyContinue
            if (
                $null -ne $stagedProcess -and
                $stagedProcess.MainWindowHandle -ne [IntPtr]::Zero -and
                $stagedProcess.MainWindowTitle -eq 'MacroDesk') {
                break
            }
        }
        Start-Sleep -Milliseconds 100
    }
    Assert-True (
        $null -ne $stagedProcess -and
        $stagedProcess.MainWindowHandle -ne [IntPtr]::Zero -and
        $stagedProcess.MainWindowTitle -eq 'MacroDesk') `
        'Staged launch.vbs did not open the MacroDesk window.'

    $visibleConsoleWindows = @(
        Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            -not $baseline.ContainsKey([int]$_.Id) -and
            @(
                'cmd',
                'conhost',
                'powershell',
                'pwsh',
                'WindowsTerminal'
            ) -contains $_.ProcessName -and
            $_.MainWindowHandle -ne [IntPtr]::Zero -and
            $_.MainWindowTitle -ne 'MacroDesk'
        }
    )
    Assert-True ($visibleConsoleWindows.Count -eq 0) `
        'A visible console window appeared during launch.vbs startup.'

    $startupLogText = ''
    $startupLogDeadline = [DateTime]::UtcNow.AddSeconds(20)
    while ([DateTime]::UtcNow -lt $startupLogDeadline) {
        $startupLogText = Read-SharedText $logPath
        if (
            $startupLogText.IndexOf(
                'startup: ' + $stageRoot,
                [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            break
        }
        Start-Sleep -Milliseconds 100
    }
    Assert-True (
        $startupLogText.IndexOf(
            'startup: ' + $stageRoot,
            [StringComparison]::OrdinalIgnoreCase) -ge 0) `
        'Staged startup did not finish after the window appeared.'

    Stop-StagedApplication `
        -ProcessId $stagedProcessId `
        -StageRoot $stageRoot
    $stagedProcessId = 0

    $logAfter = ''
    $logDeadline = [DateTime]::UtcNow.AddSeconds(10)
    while ([DateTime]::UtcNow -lt $logDeadline) {
        $logAfter = Read-SharedText $logPath
        if (
            $logAfter.IndexOf(
                'startup: ' + $stageRoot,
                [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $logAfter.IndexOf(
                'shutdown: ' + $stageRoot,
                [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            break
        }
        Start-Sleep -Milliseconds 100
    }
    Assert-True ($logAfter.StartsWith($logBefore)) `
        'The daily log prefix changed during the P9 launch.'
    $newLogText = $logAfter.Substring($logBefore.Length)
    Assert-True (
        $newLogText.IndexOf(
            'startup: ' + $stageRoot,
            [StringComparison]::OrdinalIgnoreCase) -ge 0) `
        'Staged startup was not written to the operational log.'
    Assert-True (
        $newLogText.IndexOf(
            'shutdown: ' + $stageRoot,
            [StringComparison]::OrdinalIgnoreCase) -ge 0) `
        'Staged shutdown was not written to the operational log.'
    Assert-True (
        $newLogText -notmatch
        'Option Explicit|Attribute VB_|Debug\.Print') `
        'P9 operational log contains VBA code text.'

    $p5Output = Invoke-WindowsPowerShell `
        -Executable $windowsPowerShell `
        -Arguments @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $PSScriptRoot 'test-p5-webview.ps1'),
            '-ProductRoot',
            $stageRoot,
            '-BookPath',
            $smokeBook
        ) `
        -Label 'Staged Step 1/2 WebView smoke'
    Assert-True (
        ($p5Output -join "`n") -match
        'test-p5-webview: PASS') `
        'Staged Step 1/2 WebView smoke did not report PASS.'

    $p6Output = Invoke-WindowsPowerShell `
        -Executable $windowsPowerShell `
        -Arguments @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $PSScriptRoot 'test-p6-webview.ps1'),
            '-ProductRoot',
            $stageRoot,
            '-BookPath',
            $smokeBook
        ) `
        -Label 'Staged Step 3/4 WebView smoke'
    Assert-True (
        ($p6Output -join "`n") -match
        'test-p6-webview: PASS') `
        'Staged Step 3/4 WebView smoke did not report PASS.'

    $addedPresetName = 'p9-added.md'
    $addedPresetPath = Join-Path (
        Join-Path $stageRoot 'presets') $addedPresetName
    Assert-True (-not [IO.File]::Exists($addedPresetPath)) `
        "Temporary P9 preset already exists: $addedPresetPath"
    [IO.File]::WriteAllText(
        $addedPresetPath,
        "P9 preset restart smoke.`r`n",
        (New-Object Text.UTF8Encoding($false)))

    $restartedProbeOutput = Invoke-WindowsPowerShell `
        -Executable $windowsPowerShell `
        -Arguments $probeArguments `
        -Label 'Restarted staged preset probe'
    $restartedJson = @($restartedProbeOutput | Where-Object {
        ([string]$_).TrimStart().StartsWith('{')
    } | Select-Object -Last 1)
    Assert-True ($restartedJson.Count -eq 1) `
        'Restarted staged preset probe returned no JSON.'
    $restartedPresets = [string]$restartedJson[0] |
        ConvertFrom-Json
    Assert-True (
        $restartedPresets.count -eq
        ($initialPresets.count + 1)) `
        'Preset button count did not increase after restart.'
    Assert-True (
        @($restartedPresets.files) -contains
        $addedPresetName) `
        'The added preset button is missing after restart.'

    Write-Output 'test-p9-distribution: PASS'
    Write-Output (
        'alternate-base=PASS, launch.vbs=no-console, ' +
        'lifecycle-log=PASS')
    Write-Output (
        'staged step1-4/build/self-loop=PASS, presets=' +
        $initialPresets.count + '->' +
        $restartedPresets.count)
} finally {
    if ($stagedProcessId -gt 0) {
        Stop-StagedApplication `
            -ProcessId $stagedProcessId `
            -StageRoot $stageRoot
    }
    if ($null -ne $launcher) {
        $launcher.Dispose()
    }

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()

    for ($attempt = 0; $attempt -lt 300; $attempt++) {
        if (-not [IO.Directory]::Exists($stageContainer)) {
            break
        }
        try {
            Assert-InsideDirectory $stageContainer $testdataRoot
            [IO.Directory]::Delete($stageContainer, $true)
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    Assert-True (
        -not [IO.Directory]::Exists($stageContainer)) `
        "P9 stage was not removed: $stageContainer"
}
