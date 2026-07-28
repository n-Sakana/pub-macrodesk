param(
    [string]$BookPath,
    [string]$OracleDir
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
}

# OracleDir is optional. When supplied, it must hold one file per module
# (<ModuleName>.<Extension>) whose text is compared byte for byte against the
# extracted code. Without it the run still asserts module order and counts.
$useOracle = -not [string]::IsNullOrEmpty($OracleDir)

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

function Get-CodeLines {
    param([string]$Code)

    if ($Code.Length -eq 0) {
        return ,@()
    }

    return ,@($Code -split "`r`n|`n|`r")
}

function Show-LineWindow {
    param(
        [string]$Label,
        [object[]]$Lines,
        [int[]]$Indexes
    )

    foreach ($index in $Indexes) {
        $display = $Lines[$index].Replace("`t", '<TAB>')
        Write-Output (
            '  {0} {1}: {2}' -f `
            $Label,
            ($index + 1),
            $display)
    }
}

function Get-FirstIndexes {
    param([int]$Count)

    $result = New-Object System.Collections.ArrayList
    for ($index = 0; $index -lt [Math]::Min(3, $Count); $index++) {
        [void]$result.Add($index)
    }
    return ,@($result)
}

function Get-LastIndexes {
    param([int]$Count)

    $result = New-Object System.Collections.ArrayList
    $start = [Math]::Max(0, $Count - 3)
    for ($index = $start; $index -lt $Count; $index++) {
        [void]$result.Add($index)
    }
    return ,@($result)
}

if (-not (Test-Path -LiteralPath $BookPath -PathType Leaf)) {
    throw "Workbook fixture was not found: $BookPath"
}
if ($useOracle -and
    -not (Test-Path -LiteralPath $OracleDir -PathType Container)) {
    throw "Oracle directory was not found: $OracleDir"
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$references = @(
    'System.IO.Compression',
    'System.IO.Compression.FileSystem'
)
Add-Type -TypeDefinition (Get-EngineSource) `
    -ReferencedAssemblies $references `
    -Language CSharp

$project = [MacroDesk.BookIO]::ReadProject(
    (Resolve-Path -LiteralPath $BookPath))
$expectedNames = @(
    'Sheet1',
    'ThisWorkbook',
    'AppController',
    'SystemInfo',
    'TimerUtils',
    'WindowUtils'
)
Assert-True ($project.Modules.Count -eq $expectedNames.Count) `
    'Extracted module count mismatch.'

Write-Output (
    'BOOK {0}: codepage={1}, modules={2}' -f `
    [IO.Path]::GetFileName($project.FilePath),
    $project.CodePage,
    $project.Modules.Count)

for ($moduleIndex = 0;
    $moduleIndex -lt $project.Modules.Count;
    $moduleIndex++) {
    $module = $project.Modules[$moduleIndex]
    Assert-True ($module.Name -eq $expectedNames[$moduleIndex]) `
        "Module order mismatch at $moduleIndex."

    if ($useOracle) {
        $oraclePath = Join-Path (
            Resolve-Path -LiteralPath $OracleDir) (
            $module.Name + '.' + $module.Extension)
        Assert-True (Test-Path -LiteralPath $oraclePath -PathType Leaf) `
            "Oracle file was not found: $oraclePath"
        $oracleText = [IO.File]::ReadAllText(
            $oraclePath,
            [Text.Encoding]::UTF8)
        Assert-True ($module.Code -ceq $oracleText) `
            "Oracle text mismatch: $($module.Name)"
    }

    [object[]]$lines = Get-CodeLines $module.Code
    Write-Output (
        'MODULE {0}: kind={1}, stream={2}, offset={3}, lines={4}' -f `
        $module.Name,
        $module.Kind,
        $module.StreamName,
        $module.SourceOffset,
        $lines.Count)
    Show-LineWindow 'FIRST' $lines (Get-FirstIndexes $lines.Count)
    Show-LineWindow 'LAST' $lines (Get-LastIndexes $lines.Count)
}

if ($useOracle) {
    Write-Output 'test-extract: PASS (all oracle texts are exact matches)'
} else {
    Write-Output (
        'test-extract: PASS (module order and counts; ' +
        'pass -OracleDir to also compare code text)')
}
