# MacroDesk WPF + WebView2 launcher.

$ErrorActionPreference = 'Stop'

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

    [System.Reflection.Assembly]::LoadFrom($assemblyPath) | Out-Null
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

[MacroDesk.App]::Run($baseDir)
