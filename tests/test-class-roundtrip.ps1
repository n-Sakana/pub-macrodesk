param(
    [string]$BookPath
)

# One build that changes an existing CLASS module and adds a standard
# module at the same time - the shape a single AI answer now has.
#
# The app can only ADD standard modules, but it must be able to CHANGE
# any existing module whatever its kind. tests\test-monthly-report-
# roundtrip.ps1 already covers the class edit on its own (renames, the
# calling module, the attribute header, optional Excel equivalence).
# This test covers what that one does not: a class edit and an addition
# in the same BuildCopy, and every untouched module staying byte for
# byte identical afterwards.
#
# Usage:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass `
#       -File tests\test-class-roundtrip.ps1

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\input_monthly_report.xlsm'
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

function Get-Module {
    param(
        [MacroStudio.VbaProjectData]$Project,
        [string]$Name
    )

    $module = $Project.Modules |
        Where-Object { $_.Name -eq $Name } |
        Select-Object -First 1
    Assert-True ($null -ne $module) "Module was not found: $Name"
    return $module
}

function Join-FullCode {
    param(
        [string]$AttributeHeader,
        [string]$Code
    )

    # Mirrors joinFinalCode() in assets\js\app.js: the app sends the
    # attribute header it extracted plus the visible code the AI edited.
    if ([string]::IsNullOrEmpty($AttributeHeader)) {
        return $Code
    }
    if ($AttributeHeader.EndsWith("`r`n")) {
        return $AttributeHeader + $Code
    }
    return $AttributeHeader + "`r`n" + $Code
}

if (-not ('MacroStudio.BookIO' -as [type])) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -TypeDefinition (Get-EngineSource) `
        -ReferencedAssemblies @(
            'System.IO.Compression',
            'System.IO.Compression.FileSystem') `
        -Language CSharp
}

$BookPath = (Resolve-Path -LiteralPath $BookPath).Path
Assert-True ([IO.File]::Exists($BookPath)) "Test book is missing: $BookPath"

$outputDir = Join-Path ([IO.Path]::GetTempPath()) (
    'macrostudio-class-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($outputDir)
$outputPath = Join-Path $outputDir 'class_roundtrip.xlsm'

try {
    $source = [MacroStudio.BookIO]::ReadProject($BookPath)

    # ---- the class module has to be real, not an empty shell -------
    $sourceClass = Get-Module $source 'CReportRow'
    Assert-True (
        $sourceClass.Kind -eq [MacroStudio.VbaModuleKind]::Class) `
        "CReportRow was not read as a class module: $($sourceClass.Kind)"
    $sourceClassLines = @($sourceClass.Code -split "`r`n").Count
    Assert-True ($sourceClassLines -ge 40) `
        "The class module is too small to be a real test: $sourceClassLines"
    Assert-True (
        $sourceClass.AttributeHeader.Contains('VB_PredeclaredId') -and
        $sourceClass.AttributeHeader.Contains('VB_Exposed')) `
        'The class attribute header lost its class attributes.'

    # The AI only ever sees the visible code, so the change is made on
    # the visible code alone.
    $changedClassCode = $sourceClass.Code.Replace(
        'Option Explicit',
        "Option Explicit`r`n`r`n' Reviewed by MacroStudio class roundtrip test.")
    Assert-True ($changedClassCode -ne $sourceClass.Code) `
        'The class code change did not apply.'

    $sourceStandard = Get-Module $source 'CommonUtil'
    Assert-True (
        $sourceStandard.Kind -eq [MacroStudio.VbaModuleKind]::Standard) `
        'CommonUtil is not a standard module.'
    $changedStandardCode = $sourceStandard.Code.Replace(
        'Option Explicit',
        "Option Explicit`r`n`r`n' Reviewed by MacroStudio class roundtrip test.")
    Assert-True ($changedStandardCode -ne $sourceStandard.Code) `
        'The standard code change did not apply.'

    $changes = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $changes.Add(
        'CReportRow',
        (Join-FullCode $sourceClass.AttributeHeader $changedClassCode))
    $changes.Add(
        'CommonUtil',
        (Join-FullCode $sourceStandard.AttributeHeader $changedStandardCode))

    # A package may also add a helper module. Additions stay standard.
    $additionCode = "Option Explicit`r`n`r`n" +
        "Public Function RoundtripTag() As String`r`n" +
        "    RoundtripTag = ""macrostudio""`r`n" +
        "End Function`r`n"
    $addition = New-Object MacroStudio.VbaModuleAddition(
        'RoundtripHelper',
        $additionCode)
    $additions = New-Object 'System.Collections.Generic.List[MacroStudio.VbaModuleAddition]'
    $additions.Add($addition)

    $result = [MacroStudio.BookIO]::BuildCopy(
        $BookPath,
        $outputPath,
        $changes,
        $additions)
    Assert-True $result.Success (
        'BuildCopy failed: ' + $result.ErrorCode + ' ' + $result.Message)
    foreach ($moduleResult in $result.Results) {
        Assert-True ($moduleResult.Result -eq 'written') (
            'Module was not written: ' + $moduleResult.Name + ' -> ' +
            $moduleResult.Result + ' ' + $moduleResult.Message)
    }

    # ---- read the built book back ---------------------------------
    $output = [MacroStudio.BookIO]::ReadProject($result.OutputPath)
    $outputClass = Get-Module $output 'CReportRow'

    Assert-True (
        $outputClass.Kind -eq [MacroStudio.VbaModuleKind]::Class) `
        "The rebuilt CReportRow is no longer a class: $($outputClass.Kind)"
    Assert-True ($outputClass.Extension -eq 'cls') `
        "The rebuilt class extension changed: $($outputClass.Extension)"
    Assert-True (
        $outputClass.AttributeHeader -eq $sourceClass.AttributeHeader) `
        'The class attribute header was not preserved.'
    Assert-True ($outputClass.Code -eq $changedClassCode) `
        'The changed class code was not written back.'
    Assert-True (
        $outputClass.Code.Contains(
            'Reviewed by MacroStudio class roundtrip test.')) `
        'The class edit is missing from the rebuilt book.'
    Assert-True (-not $outputClass.Code.Contains('Attribute VB_')) `
        'Attribute lines leaked into the visible class code.'

    $outputStandard = Get-Module $output 'CommonUtil'
    Assert-True (
        $outputStandard.Kind -eq [MacroStudio.VbaModuleKind]::Standard) `
        'The rebuilt CommonUtil is no longer a standard module.'
    Assert-True ($outputStandard.Code -eq $changedStandardCode) `
        'The changed standard code was not written back.'

    $outputAdded = Get-Module $output 'RoundtripHelper'
    Assert-True (
        $outputAdded.Kind -eq [MacroStudio.VbaModuleKind]::Standard) `
        'The added module is not a standard module.'
    Assert-True ($outputAdded.Code.Contains('RoundtripTag')) `
        'The added module lost its code.'

    # ---- everything else must be untouched ------------------------
    $changedNames = @{}
    $changedNames['CReportRow'] = $true
    $changedNames['CommonUtil'] = $true
    $changedNames['RoundtripHelper'] = $true

    $untouched = 0
    foreach ($module in $source.Modules) {
        if ($changedNames.ContainsKey($module.Name)) {
            continue
        }
        $after = Get-Module $output $module.Name
        Assert-True ($after.Kind -eq $module.Kind) (
            'Module kind changed: ' + $module.Name)
        Assert-True ($after.FullCode -eq $module.FullCode) (
            'Untouched module source changed: ' + $module.Name)
        Assert-True (
            $after.AttributeHeader -eq $module.AttributeHeader) (
            'Untouched module attributes changed: ' + $module.Name)
        $untouched++
    }
    Assert-True ($untouched -ge 5) `
        "Too few untouched modules were checked: $untouched"

    Assert-True (
        $output.Modules.Count -eq $source.Modules.Count + 1) (
        'Module count is wrong after build: ' + $output.Modules.Count)

    $classCount = @($output.Modules |
        Where-Object { $_.Kind -eq [MacroStudio.VbaModuleKind]::Class }).Count
    $sourceClassCount = @($source.Modules |
        Where-Object { $_.Kind -eq [MacroStudio.VbaModuleKind]::Class }).Count
    Assert-True ($classCount -eq $sourceClassCount) (
        'The class module count changed: ' + $classCount +
        ' (expected ' + $sourceClassCount + ')')

    Write-Output 'test-class-roundtrip: OK'
    Write-Output (
        'class=CReportRow lines=' + $sourceClassLines +
        ', changed=2, added=1, untouched=' + $untouched)
}
finally {
    if ([IO.Directory]::Exists($outputDir)) {
        [IO.Directory]::Delete($outputDir, $true)
    }
}
