# MacroStudio WPF + WebView2 launcher.

$ErrorActionPreference = 'Stop'

# launch.vbs shows a message box only for this exit code, so that a forced
# shutdown of a running application never raises a false startup error.
$startupFailureExitCode = 3

function Write-LauncherLog {
    param(
        [string]$Level,
        [string]$Message
    )

    try {
        $logDir = Join-Path $env:LOCALAPPDATA 'MacroStudio\logs'
        if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logPath = Join-Path $logDir (
            'macrostudio_' + (Get-Date -Format 'yyyyMMdd') + '.log')
        $line = '[' + (Get-Date -Format 'HH:mm:ss') + '] ' +
            '[' + $Level + '] ' + $Message

        # HostServices.WriteLog appends UTF-8 without a byte order mark.
        # Match it so the daily log never gains a mark in the middle.
        [System.IO.File]::AppendAllText(
            $logPath,
            $line + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))
    }
    catch {
    }
}

try {
    $baseDir = $PSScriptRoot
    $libDir = Join-Path $baseDir 'lib'
    $srcDir = Join-Path $baseDir 'src'

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Web.Extensions
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $env:Path = $libDir + [System.IO.Path]::PathSeparator + $env:Path

    $webViewAssemblies = @(
        (Join-Path $libDir 'Microsoft.Web.WebView2.Core.dll')
        (Join-Path $libDir 'Microsoft.Web.WebView2.Wpf.dll')
    )

    foreach ($assemblyPath in $webViewAssemblies) {
        if (-not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) {
            throw "Required WebView2 assembly is missing: $assemblyPath"
        }

        # A copy that arrived as a zip download carries a Mark of the Web
        # (a Zone.Identifier stream), and Assembly::LoadFrom refuses such a
        # file with HRESULT 0x80131515. Handing the bytes to Assembly::Load
        # loads the same assembly without touching that stream.
        [System.Reflection.Assembly]::Load(
            [System.IO.File]::ReadAllBytes($assemblyPath)) | Out-Null
    }

    $csFiles = Get-ChildItem -LiteralPath $srcDir -Filter '*.cs' |
        Sort-Object -Property Name

    if (@($csFiles).Count -eq 0) {
        throw "No C# source files were found in: $srcDir"
    }

    $combined = ($csFiles | ForEach-Object {
        [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
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
        (Join-Path $libDir 'Microsoft.Web.WebView2.Core.dll')
        (Join-Path $libDir 'Microsoft.Web.WebView2.Wpf.dll')
    )

    Add-Type -TypeDefinition $source -ReferencedAssemblies $references -Language CSharp

    [MacroStudio.App]::Run($baseDir)
}
catch {
    $location = ''
    if ($null -ne $_.InvocationInfo) {
        $location = ' (' + $_.InvocationInfo.ScriptName + ':' +
            $_.InvocationInfo.ScriptLineNumber + ')'
    }
    $detail = 'launcher failed' + $location + ' ' + $_.Exception.ToString()

    Write-LauncherLog 'ERROR' $detail

    # launch.bat keeps this text on screen; launch.vbs points at the log file.
    [Console]::Error.WriteLine('MacroStudio: ' + $detail)

    exit $startupFailureExitCode
}
