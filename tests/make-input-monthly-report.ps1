param(
    [string]$OutPath,
    [string]$SourceDir,
    [switch]$SkipRunCheck
)

# Builds testdata\input_monthly_report.xlsm: the "general refactoring"
# input sample for MacroStudio.
#
# The sample is a genuine macro-enabled workbook with a real VBA project
# (5 standard modules imported from tests\fixtures\monthly-report\*.bas).
# It is NOT sanitized, NOT an empty shell and NOT a copy of extracted
# output - Excel opens it, compiles it and runs it.
#
# Business content: a monthly sales roll-up of the kind a back office
# grows over several years. It reads the detail / product master /
# branch master / settings sheets and rebuilds the monthly summary,
# the per-branch report and the exception list.
#
# Everything is deterministic: demo data comes from a fixed seed, the
# target month comes from the settings sheet, and the macro touches no
# file, network, Shell, Win32 API or WMI. The only value that differs
# between runs is the "created at" stamp in summary!B3, which the
# equivalence test deliberately ignores.
#
# The workbook ships in a pre-run state: the judgement column and the
# three output sheets still hold the previous month (2026-05) result,
# so a run visibly and verifiably replaces them.
#
# Related files (all specific to this sample):
#   tests\fixtures\monthly-report\*.bas            VBA sources
#   tests\fixtures\monthly-report\workbook-data.json  Japanese literals
#   tests\test-input-monthly-report.ps1            structure / smell check
#   tests\test-monthly-report-equivalence.ps1      before/after behaviour
#
# Japanese text is never inlined here: every tests\*.ps1 in this repo is
# ASCII-only and reads localized strings from a UTF-8 data file.
#
# Usage:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass `
#       -File tests\make-input-monthly-report.ps1
#
# -SourceDir builds the same workbook from a different set of .bas/.cls
# files, which is how a REFACTORED version gets a workbook that Excel
# has genuinely compiled:
#
#   ... -SourceDir <refactored sources> -OutPath testdata\refactored.xlsm
#   ... -File tests\test-monthly-report-equivalence.ps1 `
#          -BookPath testdata\refactored.xlsm
#
# Use this path, not a MacroStudio rebuild, when the question is "does the
# refactored code still produce the same figures". A rebuilt workbook
# keeps the original compiled p-code (SPEC 9.3 leaves _VBA_PROJECT and
# each module's PerformanceCache untouched), and VBA runs the p-code,
# so running one measures the OLD code. tests\test-monthly-report-
# roundtrip.ps1 detects and reports that explicitly.
#
# Requires Excel with "Trust access to the VBA project object model"
# enabled (HKCU:\Software\Microsoft\Office\16.0\Excel\Security\AccessVBOM = 1).

$ErrorActionPreference = 'Stop'

$fixtureDir = Join-Path $PSScriptRoot 'fixtures\monthly-report'
$testdataRoot = Join-Path $PSScriptRoot '..\testdata'
if (-not [IO.Directory]::Exists($testdataRoot)) {
    [void][IO.Directory]::CreateDirectory($testdataRoot)
}
$testdataRoot = (Resolve-Path -LiteralPath $testdataRoot).Path

if ([string]::IsNullOrEmpty($OutPath)) {
    $OutPath = Join-Path $testdataRoot 'input_monthly_report.xlsm'
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

$dataPath = Join-Path $fixtureDir 'workbook-data.json'
Assert-True ([IO.File]::Exists($dataPath)) ('Missing data file: ' + $dataPath)
$data = [IO.File]::ReadAllText($dataPath, [Text.Encoding]::UTF8) |
    ConvertFrom-Json

$products = @($data.products)
$branches = @($data.branches)
$staff = @($data.staff)
$sheetNames = @($data.sheetOrder)

# ------------------------------------------------------------------
# Deterministic pseudo random source (fixed seed, never Get-Random).
# ------------------------------------------------------------------
$script:Seed = [int64]20260601

function Get-NextRandom {
    $script:Seed = ([int64]1103515245 * $script:Seed + [int64]12345) %
        [int64]2147483648
    return $script:Seed
}

function Get-RandomInt {
    param(
        [int]$Low,
        [int]$High
    )

    $r = Get-NextRandom
    return [int]($Low + ($r % ($High - $Low + 1)))
}

function Get-Quantity {
    param([string]$Tier)

    if ($Tier -eq 'H') {
        return (Get-RandomInt 5 40)
    }
    if ($Tier -eq 'M') {
        return (Get-RandomInt 2 8)
    }
    return (Get-RandomInt 1 3)
}

# ------------------------------------------------------------------
# Detail rows
# ------------------------------------------------------------------
$rows = New-Object System.Collections.ArrayList

function Add-DetailRow {
    param(
        [datetime]$Date,
        [string]$Branch,
        [string]$Product,
        [int]$Qty,
        [int]$Price,
        [string]$Kubun,
        [string]$Staff
    )

    # Ord makes the later sort a total order, so two builds never differ.
    [void]$rows.Add([pscustomobject]@{
        Ord     = $rows.Count
        Date    = $Date
        Branch  = $Branch
        Product = $Product
        Qty     = $Qty
        Price   = $Price
        Kubun   = $Kubun
        Staff   = $Staff
    })
}

$saleWord = [string]$data.saleWord
$returnWord = [string]$data.returnWords[0]

# 130 ordinary rows inside the target month (2026-06).
for ($i = 1; $i -le 130; $i++) {
    $p = $products[(Get-RandomInt 0 ($products.Count - 1))]
    $b = $branches[(Get-RandomInt 0 ($branches.Count - 1))]
    $day = Get-RandomInt 1 30
    $qty = Get-Quantity ([string]$p.tier)
    $price = [int]$p.price
    if ($i % 7 -eq 0) {
        # A discounted line: unit price differs from the master.
        $price = [int]([Math]::Round(([double]$p.price * 0.95) / 10) * 10)
    }
    $kubun = $saleWord
    if ($i % 9 -eq 0) {
        $kubun = $returnWord
        if ([string]$p.tier -eq 'H') {
            $qty = Get-RandomInt 1 6
        }
    }
    Add-DetailRow ([datetime]::new(2026, 6, $day)) ([string]$b.code) `
        ([string]$p.code) $qty $price $kubun `
        ([string]$staff[(Get-RandomInt 0 ($staff.Count - 1))])
}

# Hand placed rows: spelling variants, missing masters, large orders.
foreach ($s in @($data.specialRows)) {
    Add-DetailRow ([datetime]::Parse([string]$s.date)) ([string]$s.branch) `
        ([string]$s.product) ([int]$s.qty) ([int]$s.price) `
        ([string]$s.kubun) ([string]$s.staff)
}

# Rows outside the target month (previous and next month).
for ($i = 1; $i -le 12; $i++) {
    $p = $products[(Get-RandomInt 0 ($products.Count - 1))]
    $b = $branches[(Get-RandomInt 0 ($branches.Count - 1))]
    Add-DetailRow ([datetime]::new(2026, 5, (Get-RandomInt 1 31))) `
        ([string]$b.code) ([string]$p.code) (Get-Quantity ([string]$p.tier)) `
        ([int]$p.price) $saleWord `
        ([string]$staff[(Get-RandomInt 0 ($staff.Count - 1))])
}
for ($i = 1; $i -le 8; $i++) {
    $p = $products[(Get-RandomInt 0 ($products.Count - 1))]
    $b = $branches[(Get-RandomInt 0 ($branches.Count - 1))]
    Add-DetailRow ([datetime]::new(2026, 7, (Get-RandomInt 1 31))) `
        ([string]$b.code) ([string]$p.code) (Get-Quantity ([string]$p.tier)) `
        ([int]$p.price) $saleWord `
        ([string]$staff[(Get-RandomInt 0 ($staff.Count - 1))])
}

$sorted = @($rows | Sort-Object -Property Date, Ord)

# ------------------------------------------------------------------
# Branch targets, chosen so every judgement band is exercised.
# ------------------------------------------------------------------
$returnWords = @($data.returnWords)
$netByBranch = @{}
foreach ($b in $branches) {
    $netByBranch[[string]$b.code] = [double]0
}
foreach ($r in $sorted) {
    if ($r.Date.Year -ne 2026 -or $r.Date.Month -ne 6) {
        continue
    }
    if (-not $netByBranch.ContainsKey($r.Branch)) {
        continue
    }
    $amount = [double]$r.Qty * [double]$r.Price
    if ($returnWords -contains $r.Kubun) {
        $netByBranch[$r.Branch] = $netByBranch[$r.Branch] - $amount
    } else {
        $netByBranch[$r.Branch] = $netByBranch[$r.Branch] + $amount
    }
}

$targets = @{}
foreach ($b in $branches) {
    $code = [string]$b.code
    $target = [Math]::Round(($netByBranch[$code] / [double]$b.ratio) / 10000) *
        10000
    if ($target -lt 10000) {
        $target = 10000
    }
    $targets[$code] = [double]$target
}

# ------------------------------------------------------------------
# Build the workbook
# ------------------------------------------------------------------
function New-Grid {
    param(
        [int]$Rows,
        [int]$Cols
    )

    # The leading comma stops PowerShell from flattening the rank-2 array
    # on the way out of the function.
    $grid = New-Object 'object[,]' $Rows, $Cols
    return , $grid
}

$existingIds = @{}
foreach ($process in @(Get-Process -Name EXCEL -ErrorAction SilentlyContinue)) {
    $existingIds[$process.Id] = $true
}

$excel = New-Object -ComObject Excel.Application
$wb = $null
try {
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.EnableEvents = $false
    $excel.AutomationSecurity = 1
    $excel.ScreenUpdating = $false

    $wb = $excel.Workbooks.Add()
    while ($wb.Worksheets.Count -gt 1) {
        $wb.Worksheets.Item($wb.Worksheets.Count).Delete()
    }
    $wb.Worksheets.Item(1).Name = $sheetNames[0]
    for ($i = 1; $i -lt $sheetNames.Count; $i++) {
        $added = $wb.Worksheets.Add([Reflection.Missing]::Value, `
            $wb.Worksheets.Item($wb.Worksheets.Count))
        $added.Name = $sheetNames[$i]
    }

    # --- detail ---------------------------------------------------
    $ws = $wb.Worksheets.Item([string]$data.sheets.detail)
    $headers = @($data.detailHeaders)
    $n = $sorted.Count
    $grid = New-Grid ($n + 1) 9
    for ($c = 0; $c -lt 9; $c++) {
        $grid.SetValue([string]$headers[$c], 0, $c)
    }
    # A few slips were re-keyed by hand and reuse the previous number.
    # CheckDuplicateSlips has to find exactly these.
    $duplicateRows = @()
    foreach ($value in @($data.duplicateSlipRows)) {
        $duplicateRows += [int]$value
    }
    $slips = New-Object 'string[]' $n
    for ($i = 0; $i -lt $n; $i++) {
        if ($duplicateRows -contains ($i + 1) -and $i -gt 0) {
            $slips[$i] = $slips[$i - 1]
        } else {
            $slips[$i] = ('D' + ($i + 1).ToString('0000'))
        }
    }

    for ($i = 0; $i -lt $n; $i++) {
        $r = $sorted[$i]
        $grid.SetValue($slips[$i], $i + 1, 0)
        $grid.SetValue([double]$r.Date.ToOADate(), $i + 1, 1)
        $grid.SetValue($r.Branch, $i + 1, 2)
        $grid.SetValue($r.Product, $i + 1, 3)
        $grid.SetValue([double]$r.Qty, $i + 1, 4)
        $grid.SetValue([double]$r.Price, $i + 1, 5)
        $grid.SetValue($r.Kubun, $i + 1, 6)
        $grid.SetValue($r.Staff, $i + 1, 7)
        # Leave behind the judgement a 2026-05 run would have written.
        if ($r.Date.Year -eq 2026 -and $r.Date.Month -eq 5) {
            if (([double]$r.Qty * [double]$r.Price) -ge 300000) {
                $grid.SetValue([string]$data.labels.judgeLarge, $i + 1, 8)
            } else {
                $grid.SetValue([string]$data.labels.judgeNormal, $i + 1, 8)
            }
        } else {
            $grid.SetValue('', $i + 1, 8)
        }
    }
    $ws.Range($ws.Cells(1, 1), $ws.Cells($n + 1, 9)).Value2 = $grid
    $ws.Range($ws.Cells(2, 2), $ws.Cells($n + 1, 2)).NumberFormatLocal =
        'yyyy/mm/dd'
    $ws.Range('A1:I1').Font.Bold = $true
    $ws.Range('A1:I1').Interior.Color = 15917529   # RGB(217,225,242)
    $ws.Columns.Item('A:I').ColumnWidth = 12

    # --- product master -------------------------------------------
    $ws = $wb.Worksheets.Item([string]$data.sheets.product)
    $headers = @($data.productHeaders)
    $grid = New-Grid ($products.Count + 1) 4
    for ($c = 0; $c -lt 4; $c++) {
        $grid.SetValue([string]$headers[$c], 0, $c)
    }
    for ($i = 0; $i -lt $products.Count; $i++) {
        $grid.SetValue([string]$products[$i].code, $i + 1, 0)
        $grid.SetValue([string]$products[$i].name, $i + 1, 1)
        $grid.SetValue([string]$products[$i].cat, $i + 1, 2)
        $grid.SetValue([double]$products[$i].price, $i + 1, 3)
    }
    $ws.Range($ws.Cells(1, 1), $ws.Cells($products.Count + 1, 4)).Value2 = $grid
    $ws.Range('A1:D1').Font.Bold = $true
    $ws.Columns.Item('A:D').ColumnWidth = 20

    # --- branch master --------------------------------------------
    $ws = $wb.Worksheets.Item([string]$data.sheets.branch)
    $headers = @($data.branchHeaders)
    $grid = New-Grid ($branches.Count + 1) 4
    for ($c = 0; $c -lt 4; $c++) {
        $grid.SetValue([string]$headers[$c], 0, $c)
    }
    for ($i = 0; $i -lt $branches.Count; $i++) {
        $code = [string]$branches[$i].code
        $grid.SetValue($code, $i + 1, 0)
        $grid.SetValue([string]$branches[$i].name, $i + 1, 1)
        $grid.SetValue([string]$branches[$i].area, $i + 1, 2)
        $grid.SetValue([double]$targets[$code], $i + 1, 3)
    }
    $ws.Range($ws.Cells(1, 1), $ws.Cells($branches.Count + 1, 4)).Value2 = $grid
    $ws.Range('A1:D1').Font.Bold = $true
    $ws.Range($ws.Cells(2, 4), $ws.Cells($branches.Count + 1, 4)).
        NumberFormatLocal = '#,##0'
    $ws.Columns.Item('A:D').ColumnWidth = 14

    # --- settings -------------------------------------------------
    $ws = $wb.Worksheets.Item([string]$data.sheets.settings)
    $headers = @($data.settingsHeaders)
    for ($c = 0; $c -lt 3; $c++) {
        $ws.Cells(1, $c + 1).Value2 = [string]$headers[$c]
    }
    $settings = @($data.settings)
    for ($i = 0; $i -lt $settings.Count; $i++) {
        $row = $i + 2
        if ([string]$settings[$i].type -eq 'text') {
            $ws.Cells($row, 2).NumberFormatLocal = '@'
        }
        $ws.Cells($row, 1).Value2 = [string]$settings[$i].key
        if ([string]$settings[$i].type -eq 'number') {
            $ws.Cells($row, 2).Value2 = [double]$settings[$i].value
        } else {
            $ws.Cells($row, 2).Value2 = [string]$settings[$i].value
        }
        $ws.Cells($row, 3).Value2 = [string]$settings[$i].note
    }
    $ws.Range('A1:C1').Font.Bold = $true
    $ws.Columns.Item('A').ColumnWidth = 18
    $ws.Columns.Item('B').ColumnWidth = 14
    $ws.Columns.Item('C').ColumnWidth = 46

    # --- output sheets, still holding the previous month -----------
    foreach ($cell in @($data.staleCells)) {
        $target = $wb.Worksheets.Item([string]$cell.sheet)
        if ([string]$cell.type -eq 'number') {
            $target.Range([string]$cell.cell).Value2 = [double]$cell.value
        } else {
            # Text format first, or Excel turns "2026-05" style labels
            # into dates - exactly what the macro guards against too.
            $target.Range([string]$cell.cell).NumberFormatLocal = '@'
            $target.Range([string]$cell.cell).Value2 = [string]$cell.value
        }
    }
    foreach ($key in @('summary', 'report', 'staff')) {
        $target = $wb.Worksheets.Item([string]$data.sheets.$key)
        $target.Range('A1').Font.Size = 14
        $target.Range('A1').Font.Bold = $true
    }
    $wb.Worksheets.Item([string]$data.sheets.check).Range('A1:F1').Font.Bold =
        $true

    # --- template sheet the cover is pasted from -------------------
    # Formatting and a live formula live here on purpose: the macro has
    # to Copy this block, not assign values, or both are lost.
    $wsTemplate = $wb.Worksheets.Item([string]$data.sheets.template)
    foreach ($cell in @($data.template.cells)) {
        $wsTemplate.Range([string]$cell.cell).NumberFormatLocal = '@'
        $wsTemplate.Range([string]$cell.cell).Value2 = [string]$cell.value
    }
    $wsTemplate.Range('A1').Font.Size = 14
    $wsTemplate.Range('A1').Font.Bold = $true
    $wsTemplate.Range('A1:C1').Interior.Color = 12419407      # RGB(79,129,189)
    $wsTemplate.Range('A1:C1').Font.Color = 16777215          # white
    $wsTemplate.Range('A1:C6').Borders.LineStyle = 1
    $wsTemplate.Range('B5').NumberFormatLocal = '#,##0'
    $wsTemplate.Range('B5').Formula = [string]$data.template.formula
    $wsTemplate.Range('A3:A6').Font.Bold = $true
    $wsTemplate.Columns.Item('A:C').ColumnWidth = 22
    $wsTemplate.Visible = 0                                   # xlSheetHidden

    $wb.Worksheets.Item([string]$data.sheets.detail).Activate()

    # --- VBA project ----------------------------------------------
    # vbext_ct_StdModule = 1, vbext_ct_ClassModule = 2. Excel writes the
    # class preamble and the VB_Name / VB_GlobalNameSpace / VB_Creatable /
    # VB_PredeclaredId / VB_Exposed attributes itself; the .cls fixture
    # holds the body only. No OLE metadata is ever hand-written here.
    if ([string]::IsNullOrEmpty($SourceDir)) {
        $moduleOrder = @(
            @{ Name = 'CReportRow';       Kind = 2; Ext = '.cls' },
            @{ Name = 'CommonUtil';       Kind = 1; Ext = '.bas' },
            @{ Name = 'SalesRules';       Kind = 1; Ext = '.bas' },
            @{ Name = 'ReportFormatting'; Kind = 1; Ext = '.bas' },
            @{ Name = 'MonthlyReport';    Kind = 1; Ext = '.bas' },
            @{ Name = 'BranchReport';     Kind = 1; Ext = '.bas' },
            @{ Name = 'StaffSummary';     Kind = 1; Ext = '.bas' },
            @{ Name = 'CoverSheet';       Kind = 1; Ext = '.bas' }
        )
    } else {
        # A refactored version of the sample: classes first so the
        # standard modules can reference them, then whatever is there.
        $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
        $fixtureDir = $sourceRoot
        $moduleOrder = @()
        foreach ($file in @(Get-ChildItem -LiteralPath $sourceRoot `
                -Filter '*.cls' | Sort-Object Name)) {
            $moduleOrder += @{
                Name = [IO.Path]::GetFileNameWithoutExtension($file.Name)
                Kind = 2
                Ext = '.cls'
            }
        }
        foreach ($file in @(Get-ChildItem -LiteralPath $sourceRoot `
                -Filter '*.bas' | Sort-Object Name)) {
            $moduleOrder += @{
                Name = [IO.Path]::GetFileNameWithoutExtension($file.Name)
                Kind = 1
                Ext = '.bas'
            }
        }
        Assert-True ($moduleOrder.Count -gt 0) `
            ('No .bas or .cls sources found in ' + $sourceRoot)
    }
    $vbProject = $wb.VBProject
    Assert-True ($null -ne $vbProject) `
        'Excel did not expose the VBA project. Enable AccessVBOM.'
    foreach ($module in $moduleOrder) {
        $sourcePath = Join-Path $fixtureDir ([string]$module.Name + $module.Ext)
        Assert-True ([IO.File]::Exists($sourcePath)) `
            ('Missing VBA source: ' + $sourcePath)
        $code = [IO.File]::ReadAllText($sourcePath, [Text.Encoding]::UTF8)
        $component = $vbProject.VBComponents.Add([int]$module.Kind)
        $component.Name = [string]$module.Name
        $component.CodeModule.AddFromString($code)
        Assert-True ($component.Type -eq [int]$module.Kind) `
            ('Component type mismatch for ' + $module.Name + ': ' +
             $component.Type)
    }
    $expectedComponents = $moduleOrder.Count + $sheetNames.Count + 1
    Assert-True ($vbProject.VBComponents.Count -eq $expectedComponents) `
        ('Unexpected component count: ' + $vbProject.VBComponents.Count +
         ', expected ' + $expectedComponents)

    # The sample ships outside this machine, so it carries no author,
    # no company and no manager from whoever generated it.
    foreach ($property in @(
        'Author', 'Last author', 'Company', 'Manager',
        'Comments', 'Keywords', 'Category')) {
        try {
            $wb.BuiltinDocumentProperties($property).Value = ''
        } catch {
        }
    }
    $wb.RemoveDocumentInformation(99)

    if ([IO.File]::Exists($OutPath)) {
        [IO.File]::Delete($OutPath)
    }
    $wb.SaveAs($OutPath, 52)

    # --- compile + run smoke check, on the in-memory copy only -----
    if (-not $SkipRunCheck) {
        $qualified = ("'" + $wb.Name.Replace("'", "''") + "'!" +
            [string]$data.labels.entryMacro)
        [void]$excel.Run($qualified)
        $check = $wb.Worksheets.Item([string]$data.sheets.summary).
            Range('B2').Value2
        Assert-True ($check -eq [string]$data.labels.targetMonthText) `
            ('The run did not refresh the summary target month, found: ' +
             $check)
    }

    Write-Output 'make-input-monthly-report: OK'
    Write-Output ('book=' + $OutPath)
    $classNames = @($moduleOrder | Where-Object { $_.Kind -eq 2 } |
        ForEach-Object { $_.Name })
    Write-Output ('detailRows=' + $n + ', modules=' + $moduleOrder.Count +
        ', components=' + $vbProject.VBComponents.Count +
        ', classes=' + ($classNames -join '/'))
    foreach ($b in $branches) {
        $code = [string]$b.code
        Write-Output ('  ' + $code +
            ' net=' + [int]$netByBranch[$code] +
            ' target=' + [int]$targets[$code] +
            ' ratio=' + [Math]::Round($netByBranch[$code] / $targets[$code], 3))
    }
} finally {
    if ($null -ne $wb) {
        try { $wb.Close($false) } catch { }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wb)
        $wb = $null
    }
    if ($null -ne $excel) {
        try { $excel.Quit() } catch { }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        $excel = $null
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()

    foreach ($process in @(Get-Process -Name EXCEL -ErrorAction SilentlyContinue)) {
        if (-not $existingIds.ContainsKey($process.Id)) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            } catch { }
        }
    }
}
