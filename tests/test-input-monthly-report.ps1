param(
    [string]$BookPath
)

# Validates testdata\input_monthly_report.xlsm: the untouched business
# macro that serves as the general-refactoring input sample.
#
# Unlike input_win32_sleep.xlsm, this sample is not about removing an
# API. Nothing in it is wrong: it produces the correct monthly figures
# today. It is here because of HOW it is written - one huge procedure,
# duplicated aggregation, hardcoded sheet names, columns, colours and
# thresholds, Variant-heavy code, ActiveSheet/Select, global state and
# a blanket On Error Resume Next.
#
# This script checks two things:
#   - MacroStudio reads the whole project through the strict path, and
#   - the sample still LOOKS like a refactoring target.
# The second half is what stops the sample from quietly decaying into
# something already clean, which would make it useless as an input.
#
# The behaviour of the macro is covered separately, and that is the
# check to run before and after a refactoring:
#   tests\test-monthly-report-equivalence.ps1
#
# Excel execution is covered by:
#   tests\test-excel-macro.ps1 -BookPath testdata\input_monthly_report.xlsm
#       -MacroName MonthlyReport.RunMonthlyReport

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $PSScriptRoot '..\testdata\input_monthly_report.xlsm'
}

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

$resolvedBookPath = (Resolve-Path -LiteralPath $BookPath).Path
$project = [MacroStudio.BookIO]::ReadProject($resolvedBookPath)

Assert-True (-not $project.HasReadWarnings) `
    'The sample must read through the strict path without warnings.'

$standardWithCode = @()
$classWithCode = @()
$documentModules = @()
$classModules = @()
$totalLines = 0
$linesByModule = @{}
$allCode = ''

foreach ($module in $project.Modules) {
    $code = $module.Code
    $kind = $module.Kind.ToString()
    if ($kind -eq 'Standard') {
        Assert-True ($code.Length -gt 0) `
            ('Standard module has no code: ' + $module.Name)
        $standardWithCode += $module.Name
    } elseif ($kind -eq 'Class') {
        Assert-True ($code.Length -gt 0) `
            ('Class module has no code: ' + $module.Name)
        $classWithCode += $module.Name
        $classModules += $module
    } else {
        $documentModules += $module.Name
    }
    if ($code.Length -eq 0) {
        continue
    }
    $lines = [regex]::Split($code, "\r\n")
    $linesByModule[$module.Name] = $lines.Count
    $totalLines += $lines.Count
    $allCode = $allCode + $code + "`r`n"
}

# ------------------------------------------------------------------
# Shape: several standard modules, realistic size
# ------------------------------------------------------------------
Assert-True ($standardWithCode.Count -ge 7) `
    ('The sample needs at least seven standard modules with code, found ' +
     $standardWithCode.Count + '.')
Assert-True ($totalLines -ge 700) `
    ('The sample must be a realistically sized macro, found ' +
     $totalLines + ' lines.')

foreach ($name in @('CommonUtil', 'SalesRules', 'ReportFormatting',
                    'MonthlyReport', 'BranchReport', 'StaffSummary',
                    'CoverSheet')) {
    Assert-True ($standardWithCode -contains $name) `
        ('Missing expected module: ' + $name)
}

# One class module, present from the start and actually used. The
# product only creates standard modules, so this is the case that
# proves an existing class survives a refactoring round trip.
Assert-True ($classWithCode.Count -eq 1) `
    ('The sample must contain exactly one class module, found ' +
     $classWithCode.Count + '.')
Assert-True ($classWithCode -contains 'CReportRow') `
    'The class module CReportRow is missing.'
if ($classModules.Count -eq 1) {
    $classCode = $classModules[0].Code
    $classHeader = $classModules[0].AttributeHeader
    Assert-True ($classCode -match '(?m)^\s*Private\s+m\w+\s+As\s') `
        'The class must keep private backing fields.'
    Assert-True ($classCode -match '(?m)^\s*Public\s+Property\s+Get\s') `
        'The class must expose Property Get.'
    Assert-True ($classCode -match '(?m)^\s*Public\s+Property\s+Let\s') `
        'The class must expose Property Let.'
    Assert-True (
        ($classCode -match '(?m)^\s*Public\s+Sub\s') -and
        ($classCode -match '(?m)^\s*Public\s+Function\s')) `
        'The class must expose a Sub and a Function.'
    foreach ($attribute in @('VB_Name', 'VB_PredeclaredId', 'VB_Exposed')) {
        Assert-True ($classHeader -match ('Attribute\s+' + $attribute)) `
            ('The class attribute header is missing ' + $attribute + '.')
    }
}
Assert-True ($allCode -match '\bNew\s+CReportRow\b') `
    'The class must be instantiated on the real execution path.'

# The entry point the equivalence test calls by bare name.
Assert-True ($allCode -match '(?m)^\s*Public\s+Sub\s+RunMonthlyReport\s*\(') `
    'The entry procedure RunMonthlyReport must exist and be Public.'

# ------------------------------------------------------------------
# Not sanitized, not an extraction artefact
# ------------------------------------------------------------------
$sanitizedHits = ([regex]::Matches($allCode, '\[sanitized\]')).Count
$sanitizedHits += ([regex]::Matches($allCode, 'De\*\*\*\*e')).Count
Assert-True ($sanitizedHits -eq 0) `
    'The sample must not contain sanitized code markers.'

# ------------------------------------------------------------------
# No external dependency: this sample is about structure, not APIs
# ------------------------------------------------------------------
$forbidden = @(
    @('(?m)^\s*(Public\s+|Private\s+)?Declare\s', 'a Win32 Declare'),
    @('\bShell\s*\(', 'a Shell call'),
    @('CreateObject\s*\(', 'a CreateObject call'),
    @('\bGetObject\s*\(', 'a GetObject call'),
    @('\bKill\s+', 'a file delete'),
    @('\bSaveAs\b', 'a SaveAs call'),
    @('\bWorkbooks\.Open\b', 'an external workbook open'),
    @('\bOpen\s+.+\s+For\s+(Input|Output|Append|Binary|Random)\b',
      'a file open'),
    @('\bFileSystemObject\b', 'a FileSystemObject reference'),
    @('\bWScript\b', 'a WScript reference'),
    @('winmgmts', 'a WMI reference'),
    @('\bSendKeys\b', 'a SendKeys call'),
    @('\bApplication\.Quit\b', 'an Application.Quit call'),
    @('\bThisWorkbook\.Close\b', 'a workbook close')
)
foreach ($rule in $forbidden) {
    Assert-True (-not ($allCode -match $rule[0])) `
        ('The sample must not contain ' + $rule[1] + '.')
}

# ------------------------------------------------------------------
# The sample must still be worth refactoring
# ------------------------------------------------------------------
function Count-Pattern {
    param([string]$Pattern)

    return ([regex]::Matches($allCode, $Pattern)).Count
}

$smells = @{}
$smells['ActiveSheet/Selection'] = (Count-Pattern '\bActiveSheet\b') +
    (Count-Pattern '\bSelection\b')
$smells['Select/Activate'] = (Count-Pattern '\.Select\b') +
    (Count-Pattern '\.Activate\b')
$smells['On Error Resume Next'] = Count-Pattern 'On Error Resume Next'
$smells['hardcoded RGB'] = Count-Pattern 'RGB\s*\('
$smells['global state'] = Count-Pattern '(?m)^\s*Public\s+g_'
$smells['hardcoded sheet name'] = Count-Pattern 'Worksheets\s*\(\s*"'
$smells['hardcoded threshold'] = Count-Pattern '>=\s*[0-9]{4,}'
$smells['last row helper'] = (Count-Pattern '(?m)^\s*Public\s+Function\s+LastRow') +
    (Count-Pattern '(?m)^\s*Public\s+Function\s+GetLastRow')
$smells['Variant declaration'] = Count-Pattern '(?m)^\s*Dim\s+\w+\s+As\s+Variant\b'
# Cell-at-a-time reads and writes, the bulk of what a 2D-array rewrite
# would collapse.
$smells['cell-by-cell write'] = Count-Pattern '\.Cells\([^)]*\)\.Value\s*='
$smells['cell-by-cell read'] = Count-Pattern '\.Cells\([^)]*\)\.Value\b(?!\s*=)'
$smells['Copy/PasteSpecial'] = (Count-Pattern '\.Copy\b') +
    (Count-Pattern '\.PasteSpecial\b')
$smells['ReDim Preserve'] = Count-Pattern 'ReDim\s+Preserve\b'
# Bare Range(/Cells( at the start of a statement: macro-recorder residue
# that depends on whatever sheet happens to be active.
$smells['unqualified Range/Cells'] =
    (Count-Pattern '(?m)^\s*(Range|Cells)\s*\(') +
    (Count-Pattern '(?m)^\s*\w+\s*=\s*(Range|Cells)\s*\(')
$smells['ActiveWorkbook'] = Count-Pattern '\bActiveWorkbook\b'
$smells['nested key scan'] = Count-Pattern '(?m)^\s*For\s+j\s*='

$expectedMinimum = @{
    'ActiveSheet/Selection' = 5
    'Select/Activate' = 6
    'On Error Resume Next' = 4
    'hardcoded RGB' = 8
    'global state' = 6
    'hardcoded sheet name' = 12
    'hardcoded threshold' = 3
    'last row helper' = 3
    'Variant declaration' = 3
    'cell-by-cell write' = 40
    'cell-by-cell read' = 15
    'Copy/PasteSpecial' = 4
    'ReDim Preserve' = 4
    'unqualified Range/Cells' = 3
    'ActiveWorkbook' = 1
    'nested key scan' = 3
}
foreach ($key in @($expectedMinimum.Keys | Sort-Object)) {
    Assert-True ($smells[$key] -ge $expectedMinimum[$key]) `
        ('The sample lost a deliberate smell (' + $key + '): found ' +
         $smells[$key] + ', expected at least ' + $expectedMinimum[$key] + '.')
}

# One procedure has to be genuinely oversized, or there is nothing to split.
$entryLines = 0
$inEntry = $false
foreach ($line in [regex]::Split($allCode, "\r\n")) {
    if ($line -match '^\s*Public\s+Sub\s+RunMonthlyReport\s*\(') {
        $inEntry = $true
    }
    if ($inEntry) {
        $entryLines++
        if ($line -match '^\s*End\s+Sub\s*$') {
            break
        }
    }
}
Assert-True ($entryLines -ge 150) `
    ('RunMonthlyReport must stay an oversized procedure, found ' +
     $entryLines + ' lines.')

# The category list is duplicated on purpose: a refactoring should
# notice it. If both copies vanish, the sample stopped being a target.
$categoryMentions = Count-Pattern 'CategoryList'
Assert-True ($categoryMentions -ge 2) `
    ('The duplicated category list must remain, found ' +
     $categoryMentions + ' mentions.')

# Two near-identical large-order rules, one reading the settings sheet
# and one with the number baked in.
Assert-True ($allCode -match 'Function\s+IsOoguchi') `
    'IsOoguchi must remain.'
Assert-True ($allCode -match 'Function\s+IsBigAmount') `
    'The duplicated IsBigAmount rule must remain.'

# ------------------------------------------------------------------
# Traps: places where the obvious blanket rewrite is wrong
# ------------------------------------------------------------------
# These are what stop "replace every Copy", "replace every .Value with
# .Value2" and "index everything with a Dictionary" from being correct
# answers. tests\test-monthly-report-equivalence.ps1 is what actually
# catches each one; this file only guarantees the trap is still armed.

# 1. One Copy carries formatting and a live formula. Turning it into a
#    value assignment silently drops both.
Assert-True ($allCode -match 'PasteSpecial\s+xlPasteAll') `
    'The formatting-and-formula paste must remain (xlPasteAll).'
# 2. Another Copy moves values only and should become a direct
#    assignment, so the two must not be collapsed into one rule.
Assert-True ($allCode -match 'PasteSpecial\s+xlPasteValues') `
    'The values-only paste must remain (xlPasteValues).'
# 3. A date is read through .Value on purpose. .Value2 hands back a
#    Double, IsDate then fails, and every row falls out of scope.
Assert-True ($allCode -match 'IsTargetMonth\(\s*ws\.Cells\(\s*i\s*,\s*2\s*\)\.Value\s*\)') `
    'The date read through .Value must remain.'
Assert-True ($allCode -match '(?m)^\s*If\s+IsDate\(') `
    'The IsDate guard that depends on .Value must remain.'
# 4. A displayed string is read through .Text on purpose. .Value2 turns
#    "18,940,000" into 18940000.
Assert-True ($allCode -match '\.Text\b') `
    'The .Text display read must remain.'
# 5. Order-dependent output: the staff table is written in first
#    appearance order and carries a running total, so a re-keyed
#    rewrite that loses the order changes the result.
Assert-True ($allCode -match '(?m)^\s*run\s*=\s*run\s*\+') `
    'The order-dependent running total must remain.'

# ------------------------------------------------------------------
# Result
# ------------------------------------------------------------------
if ($script:Failures.Count -gt 0) {
    Write-Output 'test-input-monthly-report: FAIL'
    foreach ($failure in $script:Failures) {
        Write-Output ('  - ' + $failure)
    }
    exit 1
}

$moduleSummary = @($standardWithCode | Sort-Object | ForEach-Object {
    $_ + '=' + $linesByModule[$_]
}) -join ', '
$smellSummary = @($smells.Keys | Sort-Object | ForEach-Object {
    $_ + '=' + $smells[$_]
}) -join ', '

Write-Output 'test-input-monthly-report: PASS'
Write-Output (
    'modules=' + $project.Modules.Count +
    ', standardWithCode=' + $standardWithCode.Count +
    ', classWithCode=' + $classWithCode.Count +
    ', documentModules=' + $documentModules.Count +
    ', lines=' + $totalLines +
    ', entryProcLines=' + $entryLines)
Write-Output ('  ' + $moduleSummary)
Write-Output ('  smells: ' + $smellSummary)
Write-Output '  declares=0, shell=0, fileIO=0, sanitized=0, strictRead=ok'
