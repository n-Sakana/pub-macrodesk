param()

# Real-build verification for the manual's walkthrough case:
# applies the crafted answer package to a renamed copy of the
# repository's designated sample book through the actual engine,
# then re-reads the output and checks every module.

$ErrorActionPreference = 'Stop'
$repo = 'C:\repos\pub\macrostudio'
$scratch = Split-Path -Parent $MyInvocation.MyCommand.Path
$demoDir = Join-Path $scratch 'demo'
$runDir = Join-Path $demoDir 'MacroStudio\申請データ検証_20260730_103000'
$fixturePath = Join-Path $scratch 'capture\fixture.json'

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
Add-Type -AssemblyName System.Web.Extensions
Add-Type -TypeDefinition (Get-EngineSource) `
    -ReferencedAssemblies @(
        'System.IO.Compression',
        'System.IO.Compression.FileSystem') `
    -Language CSharp

New-Item -ItemType Directory -Force $runDir | Out-Null
$bookPath = Join-Path $demoDir '申請データ検証.xlsm'
Copy-Item -LiteralPath (Join-Path $repo 'testdata\input_win32_sleep.xlsm') `
    -Destination $bookPath -Force

$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$serializer.MaxJsonLength = [int]::MaxValue
$fixture = $serializer.DeserializeObject(
    [IO.File]::ReadAllText($fixturePath, [Text.Encoding]::UTF8))

$attributesByName = @{}
foreach ($module in $fixture['modules']) {
    $attributesByName[$module['name']] = [string]$module['attributes']
}

function Join-FinalCode([string]$attributes, [string]$code) {
    if ([string]::IsNullOrEmpty($attributes)) { return $code }
    if ($attributes.EndsWith("`r`n")) { return $attributes + $code }
    return $attributes + "`r`n" + $code
}

$changes = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$additions = New-Object 'System.Collections.Generic.List[MacroStudio.VbaModuleAddition]'
$newModuleCodes = @{}
foreach ($entry in $fixture['packageModules']) {
    $name = [string]$entry['name']
    $code = [string]$entry['code']
    if ($attributesByName.ContainsKey($name)) {
        $changes[$name] = Join-FinalCode $attributesByName[$name] $code
    } else {
        $additions.Add((New-Object MacroStudio.VbaModuleAddition($name, $code)))
        $newModuleCodes[$name] = $code
    }
}

# The signature check the real build performs (SPEC 9.1-0).
$attachProject = [MacroStudio.BookIO]::ReadProject($bookPath)
$signature = [MacroStudio.BookIO]::CreateSourceSignature($attachProject)

$outputPath = Join-Path $runDir '申請データ検証-Modified-20260730.xlsm'
$result = [MacroStudio.BookIO]::BuildCopy(
    $bookPath, $outputPath, $changes, $additions, $signature, $false)

Write-Output ("build success: {0}" -f $result.Success)
if (-not $result.Success) {
    Write-Output ("error: {0} {1}" -f $result.ErrorCode, $result.Message)
    exit 1
}
foreach ($item in $result.Results) {
    Write-Output ("  {0}: {1}" -f $item.Name, $item.Result)
}

# Re-read the output ourselves and compare every module.
$built = [MacroStudio.BookIO]::ReadProject($outputPath)
$failures = 0
foreach ($module in $built.Modules) {
    $name = $module.Name
    if ($changes.ContainsKey($name)) {
        if ($module.FullCode -cne $changes[$name]) {
            Write-Output ("MISMATCH changed module: {0}" -f $name)
            $failures++
        }
    } elseif ($newModuleCodes.ContainsKey($name)) {
        $expectedVisible = [string]$newModuleCodes[$name]
        if ($module.Code -cne $expectedVisible) {
            Write-Output ("MISMATCH new module: {0}" -f $name)
            $failures++
        }
        if ($module.Kind.ToString() -ne 'Standard') {
            Write-Output ("WRONG KIND new module: {0} {1}" -f $name, $module.Kind)
            $failures++
        }
    } else {
        $original = $attachProject.Modules | Where-Object { $_.Name -ceq $name }
        if ($null -eq $original -or $module.FullCode -cne $original.FullCode) {
            Write-Output ("MISMATCH untouched module: {0}" -f $name)
            $failures++
        }
    }
}
Write-Output ("modules in output: {0} (expected {1})" -f `
    $built.Modules.Count, ($attachProject.Modules.Count + $additions.Count))
Write-Output ("re-read comparison failures: {0}" -f $failures)
Write-Output ("output: {0}" -f $outputPath)
if ($failures -gt 0) { exit 1 }

# Assemble the real run folder beside the built book.
$outDir = Join-Path $scratch 'capture\out'
Copy-Item (Join-Path $outDir 'request.md') (Join-Path $runDir 'request.md') -Force
Copy-Item (Join-Path $outDir 'source-code.md') (Join-Path $runDir 'source-code.md') -Force
Copy-Item (Join-Path $outDir 'result.md') (Join-Path $runDir 'result.md') -Force
$diffSource = Get-ChildItem $outDir -Filter '*-diff-report.html' | Select-Object -First 1
Copy-Item $diffSource.FullName (Join-Path $runDir '申請データ検証-Diff-Report-20260730.html') -Force
Write-Output ("run folder assembled: {0}" -f $runDir)
Get-ChildItem $runDir | ForEach-Object { Write-Output ("  " + $_.Name) }
