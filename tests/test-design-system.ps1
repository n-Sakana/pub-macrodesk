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

function Test-TrueTypeFont {
    param([string]$Path)

    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) `
        ('Missing bundled font: ' + [IO.Path]::GetFileName($Path))
    $stream = [IO.File]::OpenRead($Path)
    try {
        $signature = New-Object byte[] 4
        Assert-True ($stream.Read($signature, 0, 4) -eq 4) `
            ('Bundled font is empty: ' + [IO.Path]::GetFileName($Path))
        Assert-True (
            $signature[0] -eq 0 -and
            $signature[1] -eq 1 -and
            $signature[2] -eq 0 -and
            $signature[3] -eq 0
        ) ('Bundled font is not a TrueType font: ' +
            [IO.Path]::GetFileName($Path))
    } finally {
        $stream.Dispose()
    }
}

function Get-CssProperties {
    param([string]$Body)

    $properties = @{}
    [regex]::Matches(
        $Body,
        '(?s)--(?<name>[a-z0-9-]+)\s*:\s*(?<value>[^;]+);') |
        ForEach-Object {
            $properties[$_.Groups['name'].Value] =
                $_.Groups['value'].Value.Trim()
        }
    return $properties
}

function Resolve-CssProperty {
    param(
        [hashtable]$Theme,
        [hashtable]$Base,
        [string]$Name
    )

    $value = if ($Theme.ContainsKey($Name)) {
        $Theme[$Name]
    } else {
        $Base[$Name]
    }
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        $reference = [regex]::Match(
            $value,
            '^var\(--(?<name>[a-z0-9-]+)\)$')
        if (-not $reference.Success) {
            return $value
        }
        $referenceName = $reference.Groups['name'].Value
        $value = if ($Theme.ContainsKey($referenceName)) {
            $Theme[$referenceName]
        } else {
            $Base[$referenceName]
        }
    }
    throw ('CSS token reference loop: ' + $Name)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $repoRoot 'assets'
$fontRoot = Join-Path $assetRoot 'fonts'
$variablePath = Join-Path $assetRoot 'css\variables.css'
$indexPath = Join-Path $assetRoot 'index.html'

Test-TrueTypeFont (Join-Path $fontRoot 'NotoSansJP[wght].ttf')
Test-TrueTypeFont (Join-Path $fontRoot 'UDEVGothic-Regular.ttf')
Test-TrueTypeFont (Join-Path $fontRoot 'UDEVGothic-Bold.ttf')

@('OFL-NotoSansJP.txt', 'OFL-UDEVGothic.txt') |
    ForEach-Object {
        $licensePath = Join-Path $fontRoot $_
        Assert-True (Test-Path -LiteralPath $licensePath -PathType Leaf) `
            ('Missing font license: ' + $_)
        $license = [IO.File]::ReadAllText($licensePath)
        Assert-True (
            $license -match 'SIL OPEN FONT LICENSE Version 1\.1'
        ) ('Unexpected font license text: ' + $_)
    }

$variables = [IO.File]::ReadAllText($variablePath)
Assert-True ($variables -match ':root\s*\{') `
    'The light token set is missing.'
Assert-True (
    $variables -match ':root\[data-theme="dark"\]\s*\{'
) 'The dark token set is missing.'
Assert-True (
    ([regex]::Matches($variables, 'font-display:\s*block')).Count -eq 3
) 'All bundled font faces must block fallback painting.'

$rootMatch = [regex]::Match(
    $variables,
    '(?s):root\s*\{(?<body>.*?)\r?\n\}')
$darkMatch = [regex]::Match(
    $variables,
    '(?s):root\[data-theme="dark"\]\s*\{(?<body>.*?)\r?\n\}')
Assert-True ($rootMatch.Success -and $darkMatch.Success) `
    'The two token blocks could not be parsed.'
$lightProperties = Get-CssProperties $rootMatch.Groups['body'].Value
$darkProperties = Get-CssProperties $darkMatch.Groups['body'].Value

$lightColors = [ordered]@{
    'surface-canvas' = '#F4F6F8'
    'surface' = '#FFFFFF'
    'surface-sunken' = '#ECEFF2'
    'surface-hover' = '#FAFBFC'
    'surface-selected' = '#F2F6FB'
    'surface-code' = '#FBFCFD'
    'text' = '#1F2A37'
    'text-sub' = '#3C4B5C'
    'text-muted' = '#5D6B7A'
    'text-disabled' = '#9FACB9'
    'text-on-accent' = '#FFFFFF'
    'border' = '#CFD7DE'
    'border-subtle' = '#E2E7EC'
    'border-strong' = '#B4BFCA'
    'accent' = '#2B5C96'
    'accent-hover' = '#234C7D'
    'accent-soft' = '#E5EDF7'
    'accent-text' = '#24507F'
    'state-pending' = '#9FACB9'
    'state-staged' = '#2B5C96'
    'state-unchanged' = '#2F6339'
    'state-excluded' = '#9FACB9'
    'state-written' = '#3A7A47'
    'diff-removed-bg' = '#FBEDEE'
    'diff-removed-mark' = '#F3CDD1'
    'diff-removed-rail' = '#C25560'
    'diff-added-bg' = '#EAF5E7'
    'diff-added-mark' = '#C9E7C0'
    'diff-added-rail' = '#4C9155'
    'diff-empty-bg' = '#ECEFF2'
    'diff-gap-bg' = '#ECEFF2'
    'syn-keyword' = '#2C5EA8'
    'syn-comment' = '#567545'
    'syn-string' = '#A0582C'
    'syn-number' = '#6E4FA5'
    'syn-plain' = '#24313F'
    'danger' = '#B03E48'
    'danger-text' = '#93343C'
    'danger-soft' = '#FBE9EA'
    'success' = '#3A7A47'
    'success-text' = '#2F6339'
    'success-soft' = '#E4F1E4'
    'ring-inset' = '#FFFFFF'
    'focus-color' = '#9DBBDE'
    'guide-color' = '#2B5C96'
}
$darkColors = [ordered]@{
    'surface-canvas' = '#14171B'
    'surface' = '#1C2127'
    'surface-sunken' = '#101317'
    'surface-hover' = '#232931'
    'surface-selected' = '#1E2A3A'
    'surface-code' = '#191E24'
    'text' = '#E9EDF2'
    'text-sub' = '#C2CBD6'
    'text-muted' = '#97A3B1'
    'text-disabled' = '#5C6874'
    'text-on-accent' = '#FFFFFF'
    'border' = '#333B45'
    'border-subtle' = '#272E37'
    'border-strong' = '#46515D'
    'accent' = '#3D72B4'
    'accent-hover' = '#4A80C4'
    'accent-soft' = '#223650'
    'accent-text' = '#8FB8E8'
    'state-pending' = '#6B7683'
    'state-staged' = '#3D72B4'
    'state-unchanged' = '#83BD8F'
    'state-excluded' = '#6B7683'
    'state-written' = '#37804A'
    'diff-removed-bg' = '#362026'
    'diff-removed-mark' = '#59323B'
    'diff-removed-rail' = '#C96A75'
    'diff-added-bg' = '#1F2E20'
    'diff-added-mark' = '#375139'
    'diff-added-rail' = '#63A56F'
    'diff-empty-bg' = '#14171B'
    'diff-gap-bg' = '#232931'
    'syn-keyword' = '#82B3E8'
    'syn-comment' = '#94B37E'
    'syn-string' = '#D19A72'
    'syn-number' = '#B79BE3'
    'syn-plain' = '#D6DEE7'
    'danger' = '#C25560'
    'danger-text' = '#ED9AA3'
    'danger-soft' = '#3A2226'
    'success' = '#37804A'
    'success-text' = '#8FCB99'
    'success-soft' = '#22321F'
    'ring-inset' = '#1C2127'
    'focus-color' = '#79A9DC'
    'guide-color' = '#6FA3DC'
}
foreach ($entry in $lightColors.GetEnumerator()) {
    $actual = Resolve-CssProperty `
        $lightProperties $lightProperties $entry.Key
    Assert-True ($actual -ceq $entry.Value) `
        ('Light token mismatch: --' + $entry.Key)
}
foreach ($entry in $darkColors.GetEnumerator()) {
    $actual = Resolve-CssProperty `
        $darkProperties $lightProperties $entry.Key
    Assert-True ($actual -ceq $entry.Value) `
        ('Dark token mismatch: --' + $entry.Key)
}

Get-ChildItem (Join-Path $assetRoot 'css') -Filter '*.css' -File |
    Where-Object { $_.Name -ne 'variables.css' } |
    ForEach-Object {
        $css = [IO.File]::ReadAllText($_.FullName)
        Assert-True (
            $css -notmatch '#[0-9a-fA-F]{3,8}'
        ) ('Raw color found outside variables.css: ' + $_.Name)
        Assert-True (
            $css -notmatch 'data-theme'
        ) ('Theme selector found outside variables.css: ' + $_.Name)
        $rawPixels = @(
            [regex]::Matches(
                $css,
                '(?<![0-9.])(?<value>[0-9]+(?:\.[0-9]+)?)px') |
                Where-Object {
                    [double]$_.Groups['value'].Value -ne 1
                })
        Assert-True ($rawPixels.Count -eq 0) `
            ('Raw pixel value found outside variables.css: ' + $_.Name)
    }

$index = [IO.File]::ReadAllText($indexPath)
Assert-True ($index -match 'macrodesk\.theme') `
    'The pre-paint theme initialization is missing.'
Assert-True ($index -match 'id="theme-toggle"') `
    'The theme toggle is missing.'

Write-Host 'test-design-system: PASS'
Write-Host (
    'themes=2, exact-colors=90, fonts=3, ' +
    'raw-component-colors=0, raw-pixels=0')
