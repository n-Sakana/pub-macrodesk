param(
    [string]$BookPath = 'C:\repos\pub\macrostudio\testdata\input_win32_sleep.xlsm',
    [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
$repo = 'C:\repos\pub\macrostudio'

function Get-EngineSource {
    $names = @(
        '05_Ole2.cs',
        '06_VbaCompression.cs',
        '07_VbaProject.cs',
        '08_BookIO.cs'
    )
    $combined = ($names | ForEach-Object {
        [IO.File]::ReadAllText(
            (Join-Path (Join-Path $repo 'src') $_),
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

$project = [MacroStudio.BookIO]::ReadProject(
    (Resolve-Path -LiteralPath $BookPath))

function Get-TypeName([object]$kind) {
    switch ([string]$kind) {
        'Document' { return @('document', 'ドキュメントモジュール') }
        'Form' { return @('form', 'フォームモジュール') }
        'Standard' { return @('standard', '標準モジュール') }
        'Class' { return @('class', 'クラスモジュール') }
    }
    throw "unknown kind: $kind"
}

function Count-Lines([string]$code) {
    if ($code.Length -eq 0) { return 0 }
    $normalized = $code -replace "`r`n", "`n"
    $normalized = $normalized.TrimEnd("`n")
    if ($normalized.Length -eq 0) { return 0 }
    return ($normalized -split "`n").Count
}

$modules = @()
$totalLines = 0
foreach ($module in $project.Modules) {
    $pair = Get-TypeName $module.Kind
    $lineCount = Count-Lines $module.Code
    $totalLines += $lineCount
    $modules += [pscustomobject]@{
        name = $module.Name
        type = $pair[0]
        typeLabel = $pair[1]
        ext = $module.Extension
        lineCount = $lineCount
        code = $module.Code
        attributes = $module.AttributeHeader
    }
}

$book = [pscustomobject]@{
    name = [IO.Path]::GetFileName($project.FilePath)
    path = $project.FilePath
    ext = [IO.Path]::GetExtension($project.FilePath).ToLowerInvariant()
    totalLines = $totalLines
    warning = $project.HasReadWarnings
}

$result = [pscustomobject]@{
    book = $book
    modules = $modules
    hasReadWarnings = $project.HasReadWarnings
    sourceDoubt = $project.HasSourceDoubt()
    codePage = $project.CodePage
}

$json = ConvertTo-Json -InputObject $result -Depth 6
if ([string]::IsNullOrEmpty($OutPath)) {
    Write-Output $json
} else {
    [IO.File]::WriteAllText(
        $OutPath, $json, (New-Object Text.UTF8Encoding($false)))
    Write-Output ("written: {0}" -f $OutPath)
    Write-Output ("modules={0} totalLines={1} warning={2}" -f `
        $modules.Count, $totalLines, $project.HasReadWarnings)
    foreach ($m in $modules) {
        Write-Output ("  {0} ({1}, {2} lines)" -f $m.name, $m.typeLabel, $m.lineCount)
    }
}
