param(
    [string]$BookPath,
    [switch]$RunEquivalence,
    [switch]$Keep
)

# Round-trip check for the input_monthly_report sample.
#
# Three books are rebuilt through MacroStudio's own writer:
#
#   1. IDENTITY   - every editable module, standard and class alike, is
#      handed back byte for byte. The engine must report
#      skipped_no_change and the rebuilt workbook must read, open and
#      behave exactly like the original.
#   2. RENAMED    - two procedures are renamed across module boundaries
#      (IsBigAmount -> IsLargeOrder, LastRow1 -> GetLastRowOfColumnA).
#      A miniature general refactoring: several modules change at once,
#      call sites move, and the business result must not.
#   3. CLASSEDIT  - the class module CReportRow that already exists in
#      the sample is edited (a property and a method are renamed) along
#      with its caller. This is the case that matters for class support:
#      MacroStudio must write a class module back as a class, keep its
#      attribute header intact, and leave Excel able to compile and run
#      it. It is deliberately NOT a test of adding a new class, which
#      the product only supports for standard modules.
#
# The class edit is assembled the way the product does it: the stored
# attribute header from extraction plus the new body. Nothing about the
# OLE container or the attributes is hand-written.
#
# IMPORTANT - what a rebuilt workbook does NOT prove:
#
# SPEC 9.3 copies _VBA_PROJECT and each module's PerformanceCache
# through untouched and leaves recompilation to Excel. Measured on
# Excel 16 (Office16, same machine and bitness), Excel does not
# recompile: it runs, and shows in the VBE, the cached p-code. The
# rewritten source sits in the module stream unread. So running a
# rebuilt workbook exercises the ORIGINAL code, and an equivalence PASS
# on one says nothing about the new code.
#
# This script therefore checks the rebuild at SOURCE level - which is
# what MacroStudio is responsible for - and separately runs a canary that
# detects the stale-p-code behaviour and reports it. Use -RunEquivalence
# only to confirm a rebuilt workbook still opens and runs; to measure a
# refactoring's behaviour, build the workbook from the refactored
# sources instead:
#
#   tests\make-input-monthly-report.ps1 -SourceDir <refactored> `
#       -OutPath testdata\refactored.xlsm
#   tests\test-monthly-report-equivalence.ps1 `
#       -BookPath testdata\refactored.xlsm
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass `
#       -File tests\test-monthly-report-roundtrip.ps1 -RunEquivalence
#
# The rebuilt books are deleted at the end unless -Keep is given.
# tests\test-roundtrip.ps1 walks every workbook under testdata\, so
# leaving them behind would quietly enlarge an unrelated test.

$ErrorActionPreference = 'Stop'

$testdataRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\testdata')).Path
if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $testdataRoot 'input_monthly_report.xlsm'
}

$data = [IO.File]::ReadAllText(
    (Join-Path $PSScriptRoot 'fixtures\monthly-report\workbook-data.json'),
    [Text.Encoding]::UTF8) | ConvertFrom-Json
$labels = $data.labels
$sheets = $data.sheets

$script:Failures = New-Object System.Collections.ArrayList

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        [void]$script:Failures.Add($Message)
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

$resolvedBook = (Resolve-Path -LiteralPath $BookPath).Path
$source = [MacroStudio.BookIO]::ReadProject($resolvedBook)
Assert-True (-not $source.HasReadWarnings) `
    'The source sample must read without warnings.'

$standardModules = @($source.Modules | Where-Object {
    $_.Kind.ToString() -eq 'Standard'
})
$classModules = @($source.Modules | Where-Object {
    $_.Kind.ToString() -eq 'Class'
})
$editableModules = @($standardModules) + @($classModules)

Assert-True ($standardModules.Count -ge 5) `
    'Expected at least five standard modules to round-trip.'
Assert-True ($classModules.Count -eq 1) `
    ('Expected exactly one class module in the sample, found ' +
     $classModules.Count + '.')

$classModule = $classModules[0]
Assert-True ($classModule.Name -eq 'CReportRow') `
    ('Unexpected class module name: ' + $classModule.Name)
Assert-True ($classModule.Code.Length -gt 0) `
    'The class module must not be empty.'

# The attributes Excel itself generated for the class. These are what a
# rebuild has to carry through untouched.
$classAttributes = @(
    'VB_Name', 'VB_Base', 'VB_GlobalNameSpace', 'VB_Creatable',
    'VB_PredeclaredId', 'VB_Exposed')
foreach ($attribute in $classAttributes) {
    Assert-True ($classModule.AttributeHeader -match ('Attribute\s+' + $attribute)) `
        ('The class attribute header is missing ' + $attribute + '.')
}
Assert-True ($classModule.AttributeHeader -match 'VB_PredeclaredId\s*=\s*False') `
    'CReportRow must not be a predeclared class.'
Assert-True ($classModule.AttributeHeader -match 'VB_Exposed\s*=\s*False') `
    'CReportRow must not be exposed.'
Assert-True (
    $classModule.FullCode -ceq
    ($classModule.AttributeHeader + $classModule.Code)) `
    'FullCode must be exactly the attribute header plus the body.'

function Invoke-Build {
    param(
        [string]$Label,
        [string]$OutputPath,
        [hashtable]$Changes
    )

    if ([IO.File]::Exists($OutputPath)) {
        [IO.File]::Delete($OutputPath)
    }
    $dictionary = New-Object `
        'System.Collections.Generic.Dictionary[string,string]'
    foreach ($name in $Changes.Keys) {
        $dictionary.Add($name, [string]$Changes[$name])
    }
    $result = [MacroStudio.BookIO]::BuildCopy(
        $resolvedBook, $OutputPath, $dictionary)
    Assert-True $result.Success `
        ($Label + ' build failed: ' + $result.ErrorCode + ' ' +
         $result.Message)
    Assert-True ([IO.File]::Exists($OutputPath)) `
        ($Label + ' produced no workbook.')
    return $result
}

function Get-Module {
    param(
        $Project,
        [string]$Name
    )

    return ($Project.Modules | Where-Object { $_.Name -eq $Name } |
        Select-Object -First 1)
}

function Assert-ClassPreserved {
    param(
        [string]$Label,
        $Project
    )

    $rebuilt = Get-Module $Project $classModule.Name
    Assert-True ($null -ne $rebuilt) `
        ($Label + ' lost the class module.')
    if ($null -eq $rebuilt) {
        return
    }
    Assert-True ($rebuilt.Kind.ToString() -eq 'Class') `
        ($Label + ' changed the module kind to ' + $rebuilt.Kind + '.')
    Assert-True ($rebuilt.AttributeHeader -ceq $classModule.AttributeHeader) `
        ($Label + ' changed the class attribute header.')
    foreach ($attribute in $classAttributes) {
        Assert-True (
            $rebuilt.AttributeHeader -match ('Attribute\s+' + $attribute)) `
            ($Label + ' dropped the class attribute ' + $attribute + '.')
    }
    Assert-True ($rebuilt.Extension -eq $classModule.Extension) `
        ($Label + ' changed the class module extension to ' +
         $rebuilt.Extension + '.')
}

# ------------------------------------------------------------------
# 1. Identity round-trip
# ------------------------------------------------------------------
$identityPath = Join-Path $testdataRoot 'roundtrip_monthly_report_identity.xlsm'
$identityChanges = @{}
foreach ($module in $editableModules) {
    $identityChanges[$module.Name] = $module.FullCode
}
$identityResult = Invoke-Build 'identity' $identityPath $identityChanges

$skipped = 0
foreach ($item in $identityResult.Results) {
    if ($item.Result -eq 'skipped_no_change') {
        $skipped++
    }
}
Assert-True ($skipped -eq $editableModules.Count) `
    ('An unchanged round-trip must skip every module, skipped ' +
     $skipped + ' of ' + $editableModules.Count + '.')

$identityProject = [MacroStudio.BookIO]::ReadProject($identityPath)
Assert-True (-not $identityProject.HasReadWarnings) `
    'The identity round-trip must read back without warnings.'
Assert-True ($identityProject.Modules.Count -eq $source.Modules.Count) `
    ('Identity round-trip module count changed: ' +
     $identityProject.Modules.Count + ' vs ' + $source.Modules.Count + '.')
foreach ($module in $source.Modules) {
    $rebuilt = Get-Module $identityProject $module.Name
    Assert-True ($null -ne $rebuilt) `
        ('Identity round-trip lost module ' + $module.Name + '.')
    if ($null -ne $rebuilt) {
        Assert-True ($rebuilt.Code -ceq $module.Code) `
            ('Identity round-trip changed the code of ' + $module.Name + '.')
        Assert-True ($rebuilt.Kind.ToString() -eq $module.Kind.ToString()) `
            ('Identity round-trip changed the kind of ' + $module.Name + '.')
    }
}
Assert-ClassPreserved 'identity' $identityProject

# ------------------------------------------------------------------
# 2. Cross-module procedure rename, the smallest honest refactoring
# ------------------------------------------------------------------
$renamePairs = @(
    @('IsBigAmount', 'IsLargeOrder'),
    @('LastRow1', 'GetLastRowOfColumnA')
)
$renamedPath = Join-Path $testdataRoot 'roundtrip_monthly_report_renamed.xlsm'
$renamedChanges = @{}
$touched = 0
foreach ($module in $editableModules) {
    $code = $module.FullCode
    $before = $code
    foreach ($pair in $renamePairs) {
        $code = [regex]::Replace($code, ('\b' + $pair[0] + '\b'), $pair[1])
    }
    if ($code -cne $before) {
        $touched++
    }
    $renamedChanges[$module.Name] = $code
}
Assert-True ($touched -ge 3) `
    ('The rename should reach at least three modules, reached ' +
     $touched + '.')

$renamedResult = Invoke-Build 'renamed' $renamedPath $renamedChanges
$written = 0
foreach ($item in $renamedResult.Results) {
    if ($item.Result -eq 'written') {
        $written++
    }
}
Assert-True ($written -eq $touched) `
    ('Expected ' + $touched + ' modules to be written, got ' + $written + '.')

$renamedProject = [MacroStudio.BookIO]::ReadProject($renamedPath)
Assert-True (-not $renamedProject.HasReadWarnings) `
    'The renamed build must read back without warnings.'
$renamedCode = ''
foreach ($module in $renamedProject.Modules) {
    $renamedCode = $renamedCode + $module.Code + "`r`n"
}
foreach ($pair in $renamePairs) {
    Assert-True (-not ($renamedCode -match ('\b' + $pair[0] + '\b'))) `
        ('The old name ' + $pair[0] + ' survived the rebuild.')
    Assert-True ($renamedCode -match ('\b' + $pair[1] + '\b')) `
        ('The new name ' + $pair[1] + ' is missing from the rebuild.')
}
Assert-ClassPreserved 'renamed' $renamedProject

# ------------------------------------------------------------------
# 3. Editing the existing class module
# ------------------------------------------------------------------
# A property and a method of CReportRow are renamed, together with the
# standard module that calls them. Each new module body is joined to the
# attribute header captured at extraction, which is what the product
# does before it calls BuildCopy.
$classRenames = @(
    @('BranchName', 'BranchLabel'),
    @('Describe', 'DisplayLabel')
)
$classEditPath = Join-Path $testdataRoot 'roundtrip_monthly_report_classedit.xlsm'
$classEditChanges = @{}
$classTouched = @()
foreach ($module in $editableModules) {
    $body = $module.Code
    $before = $body
    foreach ($pair in $classRenames) {
        $body = [regex]::Replace($body, ('\b' + $pair[0] + '\b'), $pair[1])
    }
    if ($body -cne $before) {
        $classTouched += $module.Name
    }
    $classEditChanges[$module.Name] = $module.AttributeHeader + $body
}
Assert-True ($classTouched -contains $classModule.Name) `
    'The class edit must actually change the class module.'
Assert-True ($classTouched -contains 'BranchReport') `
    'The class edit must also change the calling standard module.'

$classEditResult = Invoke-Build 'classedit' $classEditPath $classEditChanges
$classWritten = @()
foreach ($item in $classEditResult.Results) {
    if ($item.Result -eq 'written') {
        $classWritten += $item.Name
    }
}
Assert-True ($classWritten.Count -eq $classTouched.Count) `
    ('Expected ' + $classTouched.Count + ' modules written, got ' +
     $classWritten.Count + '.')
Assert-True ($classWritten -contains $classModule.Name) `
    'The class module was not written back.'

$classEditProject = [MacroStudio.BookIO]::ReadProject($classEditPath)
Assert-True (-not $classEditProject.HasReadWarnings) `
    'The class edit build must read back without warnings.'
Assert-ClassPreserved 'classedit' $classEditProject
Assert-True ($classEditProject.Modules.Count -eq $source.Modules.Count) `
    'The class edit build changed the module count.'

$rebuiltClass = Get-Module $classEditProject $classModule.Name
if ($null -ne $rebuiltClass) {
    foreach ($pair in $classRenames) {
        Assert-True (-not ($rebuiltClass.Code -match ('\b' + $pair[0] + '\b'))) `
            ('The class still contains the old name ' + $pair[0] + '.')
        Assert-True ($rebuiltClass.Code -match ('\b' + $pair[1] + '\b')) `
            ('The class is missing the new name ' + $pair[1] + '.')
    }
    # The attribute header must not have leaked into the body, and the
    # body must not have lost its first statement.
    Assert-True (-not ($rebuiltClass.Code -match 'Attribute\s+VB_Name')) `
        'An attribute line leaked into the class body.'
    Assert-True ($rebuiltClass.Code -match '(?m)^Option Explicit') `
        'The class body lost its Option Explicit.'
}
$rebuiltCaller = Get-Module $classEditProject 'BranchReport'
if ($null -ne $rebuiltCaller) {
    Assert-True ($rebuiltCaller.Code -match '\bNew CReportRow\b') `
        'The caller no longer instantiates the class.'
    Assert-True ($rebuiltCaller.Code -match '\bBranchLabel\b') `
        'The caller was not updated to the new property name.'
}

# ------------------------------------------------------------------
# 4. Canary: does Excel actually run what MacroStudio wrote?
# ------------------------------------------------------------------
# A visible marker is written into the source of a string that the macro
# puts straight into a cell. If Excel runs the rebuilt source, the cell
# shows the marker. If it runs the cached p-code, it shows the original.
# This is reported, not asserted: it is a property of the product's
# write strategy, not of this sample.
$canaryPath = Join-Path $testdataRoot 'roundtrip_monthly_report_canary.xlsm'
$canaryMarker = 'MDCANARY'
$summaryTitle = [string]$labels.summaryTitle
$canaryChanges = @{}
$canaryHits = 0
foreach ($module in $editableModules) {
    $body = $module.Code.Replace($summaryTitle, $canaryMarker)
    if ($body -cne $module.Code) {
        $canaryHits++
    }
    $canaryChanges[$module.Name] = $module.AttributeHeader + $body
}
Assert-True ($canaryHits -eq 1) `
    ('The canary marker should touch exactly one module, touched ' +
     $canaryHits + '.')
[void](Invoke-Build 'canary' $canaryPath $canaryChanges)

$canaryProject = [MacroStudio.BookIO]::ReadProject($canaryPath)
$canarySource = ''
foreach ($module in $canaryProject.Modules) {
    $canarySource = $canarySource + $module.Code
}
Assert-True ($canarySource -match $canaryMarker) `
    'The canary marker is missing from the rebuilt source on disk.'

$canaryRuntime = '(not run)'
$canaryExcel = $null
$canaryBook = $null
try {
    $canaryExcel = New-Object -ComObject Excel.Application
    $canaryExcel.Visible = $false
    $canaryExcel.DisplayAlerts = $false
    $canaryExcel.EnableEvents = $false
    $canaryExcel.AutomationSecurity = 1
    $canaryBook = $canaryExcel.Workbooks.Open($canaryPath, 0, $true)
    [void]$canaryExcel.Run(
        "'" + $canaryBook.Name.Replace("'", "''") + "'!RunMonthlyReport")
    $shown = [string]$canaryBook.Worksheets.Item(
        [string]$sheets.summary).Range('A1').Value2
    if ($shown -eq $canaryMarker) {
        $canaryRuntime = 'recompiled (Excel ran the rebuilt source)'
    } elseif ($shown -eq $summaryTitle) {
        $canaryRuntime = 'STALE p-code (Excel ran the original compiled code)'
    } else {
        $canaryRuntime = 'unexpected value: ' + $shown
    }
} catch {
    $canaryRuntime = 'error: ' + $_.Exception.Message
} finally {
    if ($null -ne $canaryBook) {
        try { $canaryBook.Close($false) } catch { }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($canaryBook)
    }
    if ($null -ne $canaryExcel) {
        try { $canaryExcel.Quit() } catch { }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($canaryExcel)
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()
}

# ------------------------------------------------------------------
# 5. Optional: the rebuilt books still open and run
# ------------------------------------------------------------------
$equivalenceRuns = @()
if ($RunEquivalence) {
    $script = Join-Path $PSScriptRoot 'test-monthly-report-equivalence.ps1'
    foreach ($book in @($identityPath, $renamedPath, $classEditPath)) {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
            -File $script -BookPath $book 2>&1
        $text = ($output | Out-String)
        $ok = ($text -match 'test-monthly-report-equivalence: PASS')
        Assert-True $ok `
            ('Equivalence failed for ' + [IO.Path]::GetFileName($book) +
             ':' + [Environment]::NewLine + $text)
        $equivalenceRuns += ([IO.Path]::GetFileNameWithoutExtension($book).
            Replace('roundtrip_monthly_report_', '') +
            '=' + $(if ($ok) { 'PASS' } else { 'FAIL' }))
    }
}

if (-not $Keep) {
    foreach ($path in @($identityPath, $renamedPath, $classEditPath,
            $canaryPath)) {
        if ([IO.File]::Exists($path)) {
            [IO.File]::Delete($path)
        }
    }
}

if ($script:Failures.Count -gt 0) {
    Write-Output 'test-monthly-report-roundtrip: FAIL'
    foreach ($failure in $script:Failures) {
        Write-Output ('  - ' + $failure)
    }
    exit 1
}

Write-Output 'test-monthly-report-roundtrip: PASS'
Write-Output ('editable=' + $editableModules.Count +
    ' (standard=' + $standardModules.Count +
    ', class=' + $classModules.Count + ')')
Write-Output ('identity: skipped ' + $skipped + '/' + $editableModules.Count +
    ', class kind and attributes preserved')
Write-Output ('renamed: written ' + $written + '/' + $editableModules.Count)
Write-Output ('classedit: written ' + ($classWritten -join '+') +
    ', attributes byte-identical')
Write-Output ('canary: ' + $canaryRuntime)
if ($canaryRuntime -like 'STALE*') {
    Write-Output ('  note: a rebuilt workbook runs the ORIGINAL code, so ' +
        'equivalence results below only show that it still opens and runs.')
    Write-Output ('  to measure a refactoring, build from sources: ' +
        'make-input-monthly-report.ps1 -SourceDir <refactored>')
}
if ($equivalenceRuns.Count -gt 0) {
    Write-Output ('runs-and-opens: ' + ($equivalenceRuns -join ', '))
}
