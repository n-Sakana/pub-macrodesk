param(
    [string]$BookPath,
    [string]$ProductRoot,
    [string]$LightScreenshotPath,
    [string]$DarkScreenshotPath
)

$ErrorActionPreference = 'Stop'
$arguments = @{
    SmokeClass = 'ShortestPathSmoke'
}
if (-not [string]::IsNullOrEmpty($BookPath)) {
    $arguments.BookPath = $BookPath
}
if (-not [string]::IsNullOrEmpty($ProductRoot)) {
    $arguments.ProductRoot = $ProductRoot
}
if (-not [string]::IsNullOrEmpty($LightScreenshotPath)) {
    $arguments.LightScreenshotPath = $LightScreenshotPath
}
if (-not [string]::IsNullOrEmpty($DarkScreenshotPath)) {
    $arguments.DarkScreenshotPath = $DarkScreenshotPath
}

& (Join-Path $PSScriptRoot 'test-flow-webview.ps1') @arguments
Write-Output 'test-shortest-path-webview: PASS'
Write-Output (
    'one entrance, mandatory diagnosis, one repair template and one ' +
    'desired-behaviour choice reached the verified copy build')
