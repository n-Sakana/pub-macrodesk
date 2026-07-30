$ErrorActionPreference = 'Stop'

# The window carries its own mark, so the taskbar button stops showing the
# icon of the process that happens to host it (powershell.exe).
#
# The icon is drawn rather than loaded from a file, so this checks the
# picture that actually comes out: the window is built the way the app
# builds it, its icon is rasterised at the size Windows asks for, and the
# pixels are read back.

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$libDir = Join-Path $repoRoot 'lib'

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
$combined = (@($sourceFiles.FullName) | ForEach-Object {
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

# The window has to be built on an STA thread, the same as the app.
# powershell.exe already runs STA, so this only makes sure of it.
Assert-True (
    [Threading.Thread]::CurrentThread.GetApartmentState() -eq
    [Threading.ApartmentState]::STA) `
    'This test must run on an STA thread.'

$bag = @{}
try {
        $window = New-Object MacroStudio.MainWindow
        $icon = $window.Icon
        $bag['hasIcon'] = ($icon -ne $null)
        $bag['inTaskbar'] = $window.ShowInTaskbar
        Assert-True ([bool]$bag['hasIcon']) `
            'The window carries no icon at all.'

        # Rasterised at the size the taskbar uses.
        $size = 32
        $visual = New-Object Windows.Media.DrawingVisual
        $context = $visual.RenderOpen()
        $context.DrawImage(
            $icon,
            (New-Object Windows.Rect(0, 0, $size, $size)))
        $context.Close()
        $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(
            $size, $size, 96, 96,
            [Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($visual)
        $stride = $size * 4
        $pixels = New-Object byte[] ($stride * $size)
        $bitmap.CopyPixels($pixels, $stride, 0)

        $plate = 0
        $letters = 0
        $opaque = 0
        for ($y = 0; $y -lt $size; $y++) {
            for ($x = 0; $x -lt $size; $x++) {
                $i = ($y * $stride) + ($x * 4)
                $b = $pixels[$i]
                $g = $pixels[$i + 1]
                $r = $pixels[$i + 2]
                $a = $pixels[$i + 3]
                if ($a -gt 200) { $opaque++ }
                # Pre-multiplied alpha: only fully opaque pixels are
                # compared, so a blended edge is never counted as either.
                if ($a -gt 250) {
                    if ([Math]::Abs($r - 30) -le 12 -and
                        [Math]::Abs($g - 41) -le 12 -and
                        [Math]::Abs($b - 59) -le 12) { $plate++ }
                    if ([Math]::Abs($r - 125) -le 40 -and
                        [Math]::Abs($g - 172) -le 40 -and
                        [Math]::Abs($b - 255) -le 40) { $letters++ }
                }
            }
        }
        $bag['plate'] = $plate
        $bag['letters'] = $letters
        $bag['opaque'] = $opaque
        $bag['cornerAlpha'] = $pixels[3]
        $bag['centreAlpha'] =
            $pixels[(([int]($size / 2)) * $stride) +
                (([int]($size / 2)) * 4) + 3]
} finally {
    if ($window -ne $null) {
        $window.Close()
    }
}

Assert-True ([bool]$bag['inTaskbar']) `
    'The window must appear in the taskbar for its icon to matter.'

# A rounded plate, not a full square: the corner stays empty.
Assert-True ($bag['cornerAlpha'] -eq 0) `
    ("The mark must have rounded corners: corner alpha=" +
        $bag['cornerAlpha'])
Assert-True ($bag['centreAlpha'] -gt 250) `
    ("The middle of the mark must be solid: centre alpha=" +
        $bag['centreAlpha'])
# Most of the square is covered, so the icon reads as a mark rather than
# a few thin strokes.
Assert-True ($bag['opaque'] -gt 700) `
    ("The mark covers too little of the icon: " + $bag['opaque'] +
        ' of 1024')
Assert-True ($bag['plate'] -gt 400) `
    ("The plate colour of the loading screen is missing: " +
        $bag['plate'])
# The letters are what makes it MacroStudio's mark and not a blank tile.
Assert-True ($bag['letters'] -gt 30) `
    ("The letters are missing or too faint at 32px: " + $bag['letters'])

Write-Output 'test-window-icon: PASS'
Write-Output (
    ('32px icon: opaque={0}/1024, plate={1}, letters={2}, ' +
        'corner alpha={3}') -f `
    $bag['opaque'], $bag['plate'], $bag['letters'], $bag['cornerAlpha'])
