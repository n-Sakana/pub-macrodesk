param(
    [string]$BookPath
)

# Validates testdata\input_win32_sleep.xlsm: the unmodified business
# macro that serves as the pre-migration input sample for MacroStudio.
#
# The sample must look like real code written before any migration:
#   - the only Win32 API in the project is Sleep (declared once,
#     conditionally for VBA7, in one module),
#   - direct "Sleep <ms>" calls sit inline in business procedures and
#     are scattered across several standard modules,
#   - no replacement wrapper (such as WaitMilliseconds) exists yet,
#   - nothing is sanitized or commented out,
#   - the whole project reads through the strict extraction path.
#
# Excel execution is covered separately:
#   tests\test-excel-macro.ps1 -BookPath testdata\input_win32_sleep.xlsm
#       -MacroName AppController.RunApplicationReview

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\input_win32_sleep.xlsm'
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

function Get-EngineSource {
    $names = @(
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

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -TypeDefinition (Get-EngineSource) `
    -ReferencedAssemblies @(
        'System.IO.Compression',
        'System.IO.Compression.FileSystem') `
    -Language CSharp

$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$project = [MacroStudio.BookIO]::ReadProject($resolvedBookPath)

Assert-True (-not $project.HasReadWarnings) `
    'The sample must read through the strict path without warnings.'

$standardWithCode = @()
$totalLines = 0
$declareCount = 0
$sleepDeclareCount = 0
$declareModules = @{}
$callsByModule = @{}
$totalCalls = 0
$wrapperHits = 0
$sanitizedHits = 0

foreach ($module in $project.Modules) {
    $code = $module.Code
    if ($module.Kind.ToString() -eq 'Standard') {
        Assert-True ($code.Length -gt 0) `
            ('Standard module has no code: ' + $module.Name)
        $standardWithCode += $module.Name
    }
    if ($code.Length -eq 0) {
        continue
    }

    $lines = [regex]::Split($code, "\r\n")
    $totalLines += $lines.Count
    foreach ($line in $lines) {
        if ($line -match '^\s*(Public\s+|Private\s+)?Declare\s') {
            $declareCount++
            $declareModules[$module.Name] = $true
            if ($line -match 'Sleep\s+Lib\s+"kernel32"') {
                $sleepDeclareCount++
            }
        }
        if ($line -match '^\s*Sleep\s+\d') {
            $totalCalls++
            if ($callsByModule.ContainsKey($module.Name)) {
                $callsByModule[$module.Name] =
                    $callsByModule[$module.Name] + 1
            } else {
                $callsByModule[$module.Name] = 1
            }
        }
    }
    $wrapperHits += ([regex]::Matches($code, 'WaitMilliseconds')).Count
    $sanitizedHits += ([regex]::Matches($code, '\[sanitized\]')).Count
    $sanitizedHits += ([regex]::Matches($code, 'De\*\*\*\*e')).Count
}

Assert-True ($standardWithCode.Count -ge 3) `
    ('The sample needs at least three standard modules with code, ' +
     'found ' + $standardWithCode.Count + '.')
Assert-True ($totalLines -ge 250) `
    ('The sample must be a realistically sized macro, found ' +
     $totalLines + ' lines.')
Assert-True ($declareCount -ge 1) `
    'The sample must declare a Win32 API.'
Assert-True ($declareCount -eq $sleepDeclareCount) `
    ('Every Declare must be Sleep from kernel32; found ' +
     $declareCount + ' declares, ' + $sleepDeclareCount +
     ' of them Sleep.')
Assert-True ($declareModules.Keys.Count -eq 1) `
    'The Sleep declaration must live in exactly one module.'
Assert-True ($totalCalls -ge 10) `
    ('Direct Sleep calls must stay scattered through the code, ' +
     'found ' + $totalCalls + '.')
Assert-True ($callsByModule.Keys.Count -ge 3) `
    ('Sleep calls must span at least three modules, found ' +
     $callsByModule.Keys.Count + '.')

$declaringModule = @($declareModules.Keys)[0]
$otherCallModules = @($callsByModule.Keys |
    Where-Object { $_ -ne $declaringModule })
Assert-True ($otherCallModules.Count -ge 2) `
    'Sleep calls must not be centralized next to the declaration.'

Assert-True ($wrapperHits -eq 0) `
    'The sample must not contain a WaitMilliseconds wrapper yet.'
Assert-True ($sanitizedHits -eq 0) `
    'The sample must not contain sanitized code markers.'

$callSummary = @($callsByModule.Keys | Sort-Object | ForEach-Object {
    $_ + '=' + $callsByModule[$_]
}) -join ', '

Write-Output 'test-input-sample: PASS'
Write-Output (
    'modules=' + $project.Modules.Count +
    ', standardWithCode=' + $standardWithCode.Count +
    ', lines=' + $totalLines +
    ', declares=' + $declareCount + ' (Sleep only, in ' +
    $declaringModule + ')')
Write-Output (
    'calls=' + $totalCalls + ' (' + $callSummary + ')' +
    ', wrapper=0, sanitized=0, strictRead=ok')
