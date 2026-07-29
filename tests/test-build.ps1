param(
    [string]$BookPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\test_large.xlsm'
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
        [MacroDesk.VbaProjectData]$Project,
        [string]$Name
    )

    $module = $Project.Modules |
        Where-Object { $_.Name -eq $Name } |
        Select-Object -First 1
    Assert-True ($null -ne $module) "Module was not found: $Name"
    return $module
}

function New-ExpandedCode {
    param(
        [MacroDesk.VbaProjectData]$Project,
        [MacroDesk.VbaModule]$Module,
        [double]$Ratio,
        [string]$Label
    )

    $sourceLength = $Project.Encoding.GetByteCount($Module.FullCode)
    $targetLength = [int][Math]::Ceiling($sourceLength * $Ratio)
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append(
        [regex]::Replace(
            $Module.FullCode,
            '(\r\n|\r|\n)+$',
            ''))
    [void]$builder.Append("`r`n")
    $index = 0
    while ($Project.Encoding.GetByteCount(
        $builder.ToString()) -lt $targetLength) {
        $line = "' {0} expansion line {1:D5} value {2:X8}`r`n" -f `
            $Label,
            $index,
            (($index * 2654435761L) -band 0xFFFFFFFFL)
        [void]$builder.Append($line)
        $index++
    }
    return $builder.ToString()
}

function New-BoundaryCode {
    param(
        [MacroDesk.VbaProjectData]$Project,
        [MacroDesk.VbaModule]$Module
    )

    $builder = New-Object Text.StringBuilder
    [void]$builder.Append(
        [regex]::Replace(
            $Module.FullCode,
            '(\r\n|\r|\n)+$',
            ''))
    [void]$builder.Append("`r`n")
    $index = 0
    while ($true) {
        for ($batch = 0; $batch -lt 50; $batch++) {
            $value1 = ($index * 2654435761L) -band 0xFFFFFFFFL
            $value2 = ($index * 2246822519L + 3266489917L) `
                -band 0xFFFFFFFFL
            $line = (
                "' boundary {0:D5} {1:X8} {2:X8} " +
                "{3:X8} {4:X8}`r`n") -f `
                $index,
                $value1,
                $value2,
                ($value1 -bxor 0xA5A5A5A5L),
                ($value2 -bxor 0x5A5A5A5AL)
            [void]$builder.Append($line)
            $index++
        }

        $code = $builder.ToString()
        $stream = [MacroDesk.VbaProjectWriter]::CreateModuleStream(
            $Project,
            $Module,
            $code)
        if ($stream.Length -ge 4300) {
            return $code
        }
        Assert-True ($index -lt 10000) `
            'Could not create a regular-sized module stream.'
    }
}

function New-MinimalCode {
    param([MacroDesk.VbaModule]$Module)

    $header = $Module.AttributeHeader
    if ($header.Length -gt 0 -and
        -not $header.EndsWith("`r`n", [StringComparison]::Ordinal)) {
        $header += "`r`n"
    }
    return (
        $header +
        "Option Explicit`r`n" +
        "Public Sub Test(): End Sub`r`n")
}

function Assert-ExclusiveOpen {
    param([string]$Path)

    $stream = New-Object IO.FileStream(
        $Path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::ReadWrite,
        [IO.FileShare]::None)
    $stream.Dispose()
}

function Get-ZipContentMap {
    param([string]$Path)

    $result = @{}
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.Name -eq 'vbaProject.bin') {
                continue
            }

            $input = $entry.Open()
            try {
                $sha = [Security.Cryptography.SHA256]::Create()
                try {
                    $hash = [Convert]::ToBase64String(
                        $sha.ComputeHash($input))
                } finally {
                    $sha.Dispose()
                }
            } finally {
                $input.Dispose()
            }

            Assert-True (-not $result.ContainsKey($entry.FullName)) `
                "Duplicate ZIP entry: $($entry.FullName)"
            $result.Add(
                $entry.FullName,
                ('{0}:{1}' -f $entry.Length, $hash))
        }
    } finally {
        $archive.Dispose()
    }
    return $result
}

function Assert-OtherZipEntries {
    param(
        [string]$SourcePath,
        [string]$OutputPath
    )

    $before = Get-ZipContentMap $SourcePath
    $after = Get-ZipContentMap $OutputPath
    Assert-True ($after.Count -eq $before.Count) `
        'Non-VBA ZIP entry count changed.'
    foreach ($name in $before.Keys) {
        Assert-True ($after.ContainsKey($name)) `
            "Non-VBA ZIP entry is missing: $name"
        Assert-True ($after[$name] -ceq $before[$name]) `
            "Non-VBA ZIP entry content changed: $name"
    }
}

function Invoke-BuildCase {
    param(
        [string]$Label,
        [string]$SourcePath,
        [string]$OutputPath,
        [hashtable]$Changes
    )

    if (Test-Path -LiteralPath $OutputPath) {
        [IO.File]::Delete($OutputPath)
    }

    $sourceProject = [MacroDesk.BookIO]::ReadProject($SourcePath)
    $changeDictionary = New-Object `
        'System.Collections.Generic.Dictionary[string,string]'
    foreach ($name in $Changes.Keys) {
        $changeDictionary.Add($name, [string]$Changes[$name])
    }

    $result = [MacroDesk.BookIO]::BuildCopy(
        $SourcePath,
        $OutputPath,
        $changeDictionary)
    Assert-True $result.Success `
        "$Label failed: $($result.ErrorCode) $($result.Message)"
    Assert-True (
        Test-Path -LiteralPath $OutputPath -PathType Leaf) `
        "$Label output was not created."
    Assert-True ($result.Results.Count -eq $Changes.Count) `
        "$Label module result count mismatch."
    Assert-True ($result.ElapsedMilliseconds -lt 5000) `
        "$Label took more than five seconds."

    foreach ($item in $result.Results) {
        $sourceModule = Get-Module $sourceProject $item.Name
        $expectedStatus =
            if ([string]$Changes[$item.Name] -ceq
                $sourceModule.FullCode) {
                'skipped_no_change'
            } else {
                'written'
            }
        Assert-True ($item.Result -eq $expectedStatus) `
            "$Label result mismatch for $($item.Name)."
    }

    $outputProject = [MacroDesk.BookIO]::ReadProject($OutputPath)
    foreach ($sourceModule in $sourceProject.Modules) {
        $outputModule = Get-Module $outputProject $sourceModule.Name
        $expectedCode =
            if ($Changes.ContainsKey($sourceModule.Name)) {
                [string]$Changes[$sourceModule.Name]
            } else {
                $sourceModule.FullCode
            }
        Assert-True ($outputModule.FullCode -ceq $expectedCode) `
            "$Label source mismatch for $($sourceModule.Name)."
    }
    Assert-ExclusiveOpen $OutputPath

    return [pscustomobject]@{
        Label = $Label
        Path = [IO.Path]::GetFullPath($OutputPath)
        Result = $result
        Project = $outputProject
    }
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

$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$sourceProject = [MacroDesk.BookIO]::ReadProject($resolvedBookPath)
$testdataRoot = (Resolve-Path (
    Join-Path $PSScriptRoot '..\testdata')).Path
$outputRoot = Join-Path $testdataRoot 't2_6_outputs'
[void][IO.Directory]::CreateDirectory($outputRoot)
$fullOutputRoot = [IO.Path]::GetFullPath($outputRoot)
Assert-True ($fullOutputRoot.StartsWith(
    $testdataRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)) `
    'Build output directory is outside testdata.'

$knownNames = @(
    'identity.xlsm',
    'new_standard_module.xlsm',
    'one_line.xlsm',
    'plus_50_percent.xlsm',
    'plus_500_percent.xlsm',
    'large_reduction.xlsm',
    'mini_to_regular.xlsm',
    'regular_to_mini.xlsm',
    'multiple_modules.xlsm',
    'unsupported_input.xls',
    'unsupported_output.xls',
    'all_or_nothing_failure.xlsm'
)
foreach ($knownName in $knownNames) {
    $knownPath = Join-Path $fullOutputRoot $knownName
    if (Test-Path -LiteralPath $knownPath) {
        [IO.File]::Delete($knownPath)
    }
}

$appController = Get-Module $sourceProject 'AppController'
$timerUtils = Get-Module $sourceProject 'TimerUtils'
$windowUtils = Get-Module $sourceProject 'WindowUtils'

$cases = New-Object System.Collections.ArrayList

$identityChanges = @{
    AppController = $appController.FullCode
}
$identity = Invoke-BuildCase `
    'identity' `
    $resolvedBookPath `
    (Join-Path $fullOutputRoot 'identity.xlsm') `
    $identityChanges
[void]$cases.Add($identity)
Assert-OtherZipEntries $resolvedBookPath $identity.Path

$additionCode = (
    "Option Explicit`r`n`r`n" +
    "Public Sub RunAddedMacro()`r`n" +
    "    Debug.Print `"added`"`r`n" +
    "End Sub`r`n")
$additionChanges = New-Object `
    'System.Collections.Generic.Dictionary[string,string]'
$additionList = New-Object `
    'System.Collections.Generic.List[MacroDesk.VbaModuleAddition]'
$additionList.Add(
    (New-Object MacroDesk.VbaModuleAddition(
        'CommonHelpers',
        $additionCode)))
$additionPath = Join-Path `
    $fullOutputRoot `
    'new_standard_module.xlsm'
$additionResult = [MacroDesk.BookIO]::BuildCopy(
    $resolvedBookPath,
    $additionPath,
    $additionChanges,
    $additionList)
Assert-True $additionResult.Success `
    "New module build failed: $($additionResult.Message)"
Assert-True ($additionResult.Results.Count -eq 1) `
    'New module build result count mismatch.'
Assert-True (
    $additionResult.Results[0].Name -ceq 'CommonHelpers' -and
    $additionResult.Results[0].Result -eq 'written') `
    'New module build result mismatch.'
$additionProject = [MacroDesk.BookIO]::ReadProject($additionPath)
$additionModule = Get-Module $additionProject 'CommonHelpers'
Assert-True ($additionModule.Kind.ToString() -eq 'Standard') `
    'Built new module kind mismatch.'
Assert-True ($additionModule.SourceOffset -eq 0) `
    'Built new module PerformanceCache is not empty.'
Assert-True ($additionModule.Code -ceq $additionCode) `
    'Built new module code mismatch.'
Assert-OtherZipEntries $resolvedBookPath $additionPath
[void]$cases.Add([pscustomobject]@{
    Label = 'new_standard_module'
    Path = [IO.Path]::GetFullPath($additionPath)
    Result = $additionResult
    Project = $additionProject
})

$oneLineCode = [regex]::Replace(
    $appController.FullCode,
    '(\r\n|\r|\n)+$',
    '') + "`r`n' one line change`r`n"
$oneLine = Invoke-BuildCase `
    'one_line' `
    $resolvedBookPath `
    (Join-Path $fullOutputRoot 'one_line.xlsm') `
    @{ AppController = $oneLineCode }
[void]$cases.Add($oneLine)

$plus50Code = New-ExpandedCode `
    $sourceProject `
    $appController `
    1.5 `
    'plus50'
Assert-True (
    $sourceProject.Encoding.GetByteCount($plus50Code) -ge
    [Math]::Ceiling(
        $sourceProject.Encoding.GetByteCount(
            $appController.FullCode) * 1.5)) `
    '+50 percent source did not reach its target.'
$plus50 = Invoke-BuildCase `
    'plus_50_percent' `
    $resolvedBookPath `
    (Join-Path $fullOutputRoot 'plus_50_percent.xlsm') `
    @{ AppController = $plus50Code }
[void]$cases.Add($plus50)

$plus500Code = New-ExpandedCode `
    $sourceProject `
    $appController `
    6.0 `
    'plus500'
Assert-True (
    $sourceProject.Encoding.GetByteCount($plus500Code) -ge
    $sourceProject.Encoding.GetByteCount(
        $appController.FullCode) * 6) `
    '+500 percent source did not reach its target.'
$plus500 = Invoke-BuildCase `
    'plus_500_percent' `
    $resolvedBookPath `
    (Join-Path $fullOutputRoot 'plus_500_percent.xlsm') `
    @{ AppController = $plus500Code }
[void]$cases.Add($plus500)

$minimalCode = New-MinimalCode $windowUtils
Assert-True (
    $sourceProject.Encoding.GetByteCount($minimalCode) -lt
    $sourceProject.Encoding.GetByteCount(
        $windowUtils.FullCode) / 2) `
    'Large reduction did not reduce the source by half.'
$reduction = Invoke-BuildCase `
    'large_reduction' `
    $resolvedBookPath `
    (Join-Path $fullOutputRoot 'large_reduction.xlsm') `
    @{ WindowUtils = $minimalCode }
[void]$cases.Add($reduction)

$boundaryCode = New-BoundaryCode $sourceProject $appController
$boundaryStream = [MacroDesk.VbaProjectWriter]::CreateModuleStream(
    $sourceProject,
    $appController,
    $boundaryCode)
Assert-True ($boundaryStream.Length -ge 4096) `
    'Boundary increase did not create a regular stream.'
$miniToRegular = Invoke-BuildCase `
    'mini_to_regular' `
    $resolvedBookPath `
    (Join-Path $fullOutputRoot 'mini_to_regular.xlsm') `
    @{ AppController = $boundaryCode }
[void]$cases.Add($miniToRegular)
$regularModule = Get-Module $miniToRegular.Project 'AppController'
Assert-True ($regularModule.StreamData.Length -ge 4096) `
    'Built boundary stream is not regular.'

$regularToMini = Invoke-BuildCase `
    'regular_to_mini' `
    $miniToRegular.Path `
    (Join-Path $fullOutputRoot 'regular_to_mini.xlsm') `
    @{ AppController = $appController.FullCode }
[void]$cases.Add($regularToMini)
$miniModule = Get-Module $regularToMini.Project 'AppController'
Assert-True ($miniModule.StreamData.Length -lt 4096) `
    'Reduced boundary stream is not mini.'

$multiAppCode = [regex]::Replace(
    $appController.FullCode,
    '(\r\n|\r|\n)+$',
    '') + "`r`n' multiple change A`r`n"
$multiTimerCode = [regex]::Replace(
    $timerUtils.FullCode,
    '(\r\n|\r|\n)+$',
    '') + "`r`n' multiple change B`r`n"
$multiple = Invoke-BuildCase `
    'multiple_modules' `
    $resolvedBookPath `
    (Join-Path $fullOutputRoot 'multiple_modules.xlsm') `
    @{
        AppController = $multiAppCode
        TimerUtils = $multiTimerCode
    }
[void]$cases.Add($multiple)

# The extension does not decide anything: the same workbook content
# builds under an unfamiliar extension.
$renamedInput = Join-Path $fullOutputRoot 'renamed_input.xls'
$renamedOutput = Join-Path $fullOutputRoot 'renamed_output.xls'
[IO.File]::Copy($resolvedBookPath, $renamedInput, $false)
$renamedChanges = New-Object `
    'System.Collections.Generic.Dictionary[string,string]'
$renamedChanges.Add(
    'AppController',
    ([regex]::Replace($appController.FullCode, '(\r\n|\r|\n)+$', '') +
        "`r`n' renamed extension build`r`n"))
$renamedResult = [MacroDesk.BookIO]::BuildCopy(
    $renamedInput,
    $renamedOutput,
    $renamedChanges)
Assert-True $renamedResult.Success `
    'A renamed workbook extension blocked the build.'
Assert-True (Test-Path -LiteralPath $renamedOutput) `
    'A renamed workbook build produced no output.'
[IO.File]::Delete($renamedInput)
[IO.File]::Delete($renamedOutput)

# A workbook with no VBA container still fails cleanly.
$unsupportedInput = Join-Path $fullOutputRoot 'no_macro_input.xlsm'
$unsupportedOutput = Join-Path $fullOutputRoot 'no_macro_output.xlsm'
$emptyArchive = [IO.Compression.ZipFile]::Open(
    $unsupportedInput,
    [IO.Compression.ZipArchiveMode]::Create)
try {
    $emptyEntry = $emptyArchive.CreateEntry('xl/workbook.xml')
    $emptyStream = $emptyEntry.Open()
    try {
        [byte[]]$emptyPayload = [Text.Encoding]::ASCII.GetBytes('<x/>')
        $emptyStream.Write($emptyPayload, 0, $emptyPayload.Length)
    } finally {
        $emptyStream.Dispose()
    }
} finally {
    $emptyArchive.Dispose()
}
$unsupportedChanges = New-Object `
    'System.Collections.Generic.Dictionary[string,string]'
$unsupportedResult = [MacroDesk.BookIO]::BuildCopy(
    $unsupportedInput,
    $unsupportedOutput,
    $unsupportedChanges)
Assert-True (-not $unsupportedResult.Success) `
    'A macro-free input build succeeded.'
Assert-True ($unsupportedResult.ErrorCode -eq 'E-ATTACH-03') `
    'Macro-free input error code mismatch.'
Assert-True (-not (Test-Path -LiteralPath $unsupportedOutput)) `
    'A macro-free input left an output file.'
[IO.File]::Delete($unsupportedInput)

$invalidCode = (
    $appController.FullCode +
    [char]0xD83D +
    [char]0xDE00)
$failureChanges = New-Object `
    'System.Collections.Generic.Dictionary[string,string]'
$failureChanges.Add('AppController', $invalidCode)
$failureOutput = Join-Path `
    $fullOutputRoot `
    'all_or_nothing_failure.xlsm'
$failureResult = [MacroDesk.BookIO]::BuildCopy(
    $resolvedBookPath,
    $failureOutput,
    $failureChanges)
Assert-True (-not $failureResult.Success) `
    'Unencodable build succeeded.'
Assert-True ($failureResult.ErrorCode -eq 'E-BUILD-01') `
    'Unencodable build error code mismatch.'
Assert-True (-not (Test-Path -LiteralPath $failureOutput)) `
    'Failed build left an output file.'

Write-Output 'test-build: PASS'
foreach ($case in $cases) {
    Write-Output (
        '{0}: {1} ms, {2}' -f `
        $case.Label,
        $case.Result.ElapsedMilliseconds,
        $case.Path)
}
Write-Output (
    'boundary: mini={0}, regular={1}, reduced={2}' -f `
    $appController.StreamData.Length,
    $regularModule.StreamData.Length,
    $miniModule.StreamData.Length)
Write-Output (
    'negative: unsupported={0}, allOrNothing={1}' -f `
    $unsupportedResult.ErrorCode,
    $failureResult.ErrorCode)
