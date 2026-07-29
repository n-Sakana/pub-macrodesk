param(
    [string]$BookPath,
    [string]$MacroName,
    [switch]$WriteExpected,
    [switch]$ShowFingerprint
)

# Behavioural equivalence check for the input_monthly_report sample.
#
# This is the script to run BEFORE and AFTER a MacroStudio refactoring:
# a general refactoring rewrites module and procedure structure, so the
# diff is expected to be large. What must not move is the business
# result. This script pins that result down.
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass `
#       -File tests\test-monthly-report-equivalence.ps1
#   powershell.exe -NoProfile -ExecutionPolicy Bypass `
#       -File tests\test-monthly-report-equivalence.ps1 `
#       -BookPath testdata\MacroStudio\<run>\input_monthly_report_macrostudio.xlsm
#
# It runs three independent layers of checking:
#
#   1. ORACLE - the detail sheet, the two masters and the settings sheet
#      are read straight from the workbook and the whole monthly roll-up
#      is recomputed here in PowerShell, with no help from the VBA. The
#      macro output must agree with it. This survives any refactoring
#      because it only knows the business rules, not the code.
#   2. GOLDEN - a stored fingerprint (fixtures\monthly-report\expected.json)
#      of every value the report is supposed to display, including counts,
#      number formats and the judgement fill colours. This catches a
#      refactoring that changes presentation, and also catches the demo
#      data itself being regenerated differently.
#   3. IDEMPOTENCE - the macro is run a second time and the fingerprint
#      must not move. A monthly report that differs on a re-run is not
#      equivalent to one that does not.
#
# The macro is invoked by bare procedure name, so renaming or splitting
# modules does not break the check. Only the entry procedure name is
# fixed. The created-at stamp in the summary sheet is the one value
# deliberately excluded, since it is a clock reading.
#
# -WriteExpected regenerates the golden file. Do that only when the
# sample workbook is intentionally rebuilt, never to silence a failure.
#
# Japanese labels live in fixtures\monthly-report\workbook-data.json;
# this script stays ASCII-only like the rest of tests\.

$ErrorActionPreference = 'Stop'

$fixtureDir = Join-Path $PSScriptRoot 'fixtures\monthly-report'
$testdataRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\testdata')).Path

if ([string]::IsNullOrEmpty($BookPath)) {
    $BookPath = Join-Path $testdataRoot 'input_monthly_report.xlsm'
}

$data = [IO.File]::ReadAllText(
    (Join-Path $fixtureDir 'workbook-data.json'),
    [Text.Encoding]::UTF8) | ConvertFrom-Json
$L = $data.labels
$S = $data.sheets

if ([string]::IsNullOrEmpty($MacroName)) {
    $MacroName = [string]$L.entryMacro
}

$expectedPath = Join-Path $fixtureDir 'expected.json'

# ------------------------------------------------------------------
# Small helpers
# ------------------------------------------------------------------
$script:Failures = New-Object System.Collections.ArrayList
$script:Checks = 0

function Add-Failure {
    param([string]$Message)

    [void]$script:Failures.Add($Message)
}

function Assert-Equal {
    param(
        [string]$What,
        $Expected,
        $Actual
    )

    $script:Checks++
    $e = Format-Value $Expected
    $a = Format-Value $Actual
    if ($e -ne $a) {
        Add-Failure ($What + ': expected [' + $e + '], got [' + $a + ']')
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    $script:Checks++
    if (-not $Condition) {
        Add-Failure $Message
    }
}

function Format-Value {
    param($Value)

    if ($null -eq $Value) {
        return ''
    }
    if ($Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) {
        $rounded = [Math]::Round([double]$Value, 6)
        return $rounded.ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [int] -or $Value -is [long]) {
        return $Value.ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    return ([string]$Value)
}

function Get-Cell {
    param(
        $Grid,
        [int]$Row,
        [int]$Col
    )

    return $Grid.GetValue($Row, $Col)
}

function Read-Grid {
    param(
        $Sheet,
        [int]$Rows,
        [int]$Cols
    )

    $value = $Sheet.Range($Sheet.Cells(1, 1), $Sheet.Cells($Rows, $Cols)).Value2
    return , $value
}

# Ordered fingerprint of everything the report displays.
$script:Print = New-Object System.Collections.Specialized.OrderedDictionary

function Add-Print {
    param(
        [string]$Key,
        $Value
    )

    $script:Print[$Key] = Format-Value $Value
}

# ------------------------------------------------------------------
# Workbook copy (never touch the sample itself)
# ------------------------------------------------------------------
function Assert-InsideDirectory {
    param(
        [string]$Path,
        [string]$Directory
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar)
    $prefix = $fullDirectory + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith(
            $prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw ('Test path is outside the expected directory: ' + $fullPath)
    }
}

$resolvedBook = (Resolve-Path -LiteralPath $BookPath).Path
$copyPath = Join-Path $testdataRoot (
    'equiv-' + [Guid]::NewGuid().ToString('N') + '.xlsm')
Assert-InsideDirectory $copyPath $testdataRoot
[IO.File]::Copy($resolvedBook, $copyPath, $false)

$existingIds = @{}
foreach ($process in @(Get-Process -Name EXCEL -ErrorAction SilentlyContinue)) {
    $existingIds[$process.Id] = $true
}

$excel = $null
$wb = $null
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.EnableEvents = $false
    $excel.AutomationSecurity = 1
    $wb = $excel.Workbooks.Open($copyPath, 0, $true)

    $wsDetail = $wb.Worksheets.Item([string]$S.detail)
    $wsProduct = $wb.Worksheets.Item([string]$S.product)
    $wsBranch = $wb.Worksheets.Item([string]$S.branch)
    $wsSettings = $wb.Worksheets.Item([string]$S.settings)
    $wsSummary = $wb.Worksheets.Item([string]$S.summary)
    $wsReport = $wb.Worksheets.Item([string]$S.report)
    $wsCheck = $wb.Worksheets.Item([string]$S.check)
    $wsStaff = $wb.Worksheets.Item([string]$S.staff)
    $wsCover = $wb.Worksheets.Item([string]$S.cover)
    $wsTemplate = $wb.Worksheets.Item([string]$S.template)

    # --------------------------------------------------------------
    # 1. Read the inputs and build the oracle
    # --------------------------------------------------------------
    $detailRows = $wsDetail.Cells($wsDetail.Rows.Count, 1).End(-4162).Row
    $productRows = $wsProduct.Cells($wsProduct.Rows.Count, 1).End(-4162).Row
    $branchRows = $wsBranch.Cells($wsBranch.Rows.Count, 1).End(-4162).Row
    $settingRows = $wsSettings.Cells($wsSettings.Rows.Count, 1).End(-4162).Row

    $detail = Read-Grid $wsDetail $detailRows 9
    $productGrid = Read-Grid $wsProduct $productRows 4
    $branchGrid = Read-Grid $wsBranch $branchRows 4
    $settingGrid = Read-Grid $wsSettings $settingRows 3

    $settingMap = @{}
    for ($i = 2; $i -le $settingRows; $i++) {
        $key = [string](Get-Cell $settingGrid $i 1)
        $settingMap[$key.Trim()] = (Get-Cell $settingGrid $i 2)
    }
    $targetYm = ([string]$settingMap[[string]$L.targetMonth]).Trim()
    $largeAmount = [double]$settingMap[[string]$L.settingLargeAmount]

    $categories = @($data.categories)
    $returnWords = @($data.returnWords)

    # product master
    $productCodes = New-Object System.Collections.ArrayList
    $productName = @{}
    $productCat = @{}
    for ($i = 2; $i -le $productRows; $i++) {
        $code = ([string](Get-Cell $productGrid $i 1)).Trim()
        [void]$productCodes.Add($code)
        $productName[$code] = ([string](Get-Cell $productGrid $i 2)).Trim()
        $cat = ([string](Get-Cell $productGrid $i 3)).Trim()
        if ($cat -eq '') {
            $cat = [string]$L.uncategorized
        }
        $productCat[$code] = $cat
    }

    # branch master
    $branchCodes = New-Object System.Collections.ArrayList
    $branchName = @{}
    $branchArea = @{}
    $branchTarget = @{}
    for ($i = 2; $i -le $branchRows; $i++) {
        $code = ([string](Get-Cell $branchGrid $i 1)).Trim()
        [void]$branchCodes.Add($code)
        $branchName[$code] = ([string](Get-Cell $branchGrid $i 2)).Trim()
        $branchArea[$code] = ([string](Get-Cell $branchGrid $i 3)).Trim()
        $branchTarget[$code] = [double](Get-Cell $branchGrid $i 4)
    }

    # accumulators
    $matrix = @{}
    $branchSale = @{}
    $branchReturn = @{}
    foreach ($code in $branchCodes) {
        $branchSale[$code] = [double]0
        $branchReturn[$code] = [double]0
        $row = @{}
        foreach ($cat in $categories) {
            $row[$cat] = [double]0
        }
        $matrix[$code] = $row
    }

    $saleCount = 0
    $returnCount = 0
    $saleAmount = [double]0
    $returnAmount = [double]0
    $outOfScope = 0
    $noMasterCount = 0
    $largeCount = 0
    $expectedChecks = New-Object System.Collections.ArrayList
    $judgeCounts = @{}
    $blankJudge = 0

    # In-month rows in sheet order, for the duplicate-slip pass that
    # runs after the main loop.
    $inMonthRows = New-Object System.Collections.ArrayList

    # Staff totals, kept in first-appearance order on purpose: the
    # report is written in that order and the running total depends
    # on it.
    $staffOrder = New-Object System.Collections.ArrayList
    $staffCount = @{}
    $staffSale = @{}
    $staffReturn = @{}

    # product ranking accumulators, in the order the macro builds them
    $rankCodes = New-Object System.Collections.ArrayList
    foreach ($code in $productCodes) {
        [void]$rankCodes.Add($code)
    }
    $rankAmount = @{}
    $rankQty = @{}
    $rankName = @{}
    $rankCat = @{}
    foreach ($code in $rankCodes) {
        $rankAmount[$code] = [double]0
        $rankQty[$code] = [double]0
        $rankName[$code] = $productName[$code]
        $rankCat[$code] = $productCat[$code]
    }

    for ($i = 2; $i -le $detailRows; $i++) {
        $slip = ([string](Get-Cell $detail $i 1)).Trim()
        $rawDate = Get-Cell $detail $i 2
        $bcd = ([string](Get-Cell $detail $i 3)).Trim()
        $pcd = ([string](Get-Cell $detail $i 4)).Trim()
        $qty = [double](Get-Cell $detail $i 5)
        $price = [double](Get-Cell $detail $i 6)
        $kubun = ([string](Get-Cell $detail $i 7)).Trim()
        $person = ([string](Get-Cell $detail $i 8)).Trim()
        $amount = $qty * $price

        $ym = ''
        if ($null -ne $rawDate) {
            $ym = [datetime]::FromOADate([double]$rawDate).ToString('yyyyMM')
        }
        if ($ym -ne $targetYm) {
            $outOfScope++
            $blankJudge++
            continue
        }

        $isReturn = ($returnWords -contains $kubun)
        $hasProduct = $productCat.ContainsKey($pcd)
        $hasBranch = $branchName.ContainsKey($bcd)

        [void]$inMonthRows.Add([pscustomobject]@{
            Slip = $slip
            Branch = $bcd
            Product = $pcd
            Amount = $amount
        })

        if (-not $staffCount.ContainsKey($person)) {
            [void]$staffOrder.Add($person)
            $staffCount[$person] = 0
            $staffSale[$person] = [double]0
            $staffReturn[$person] = [double]0
        }
        $staffCount[$person] = $staffCount[$person] + 1
        if ($isReturn) {
            $staffReturn[$person] = $staffReturn[$person] + $amount
        } else {
            $staffSale[$person] = $staffSale[$person] + $amount
        }

        $cat = [string]$L.uncategorized
        if ($hasProduct) {
            $cat = $productCat[$pcd]
        } else {
            $noMasterCount++
            [void]$expectedChecks.Add(@(
                [string]$L.kindNoProduct, $slip, $bcd, $pcd,
                [string]$L.noProductText, $amount))
        }
        if (-not $hasBranch) {
            [void]$expectedChecks.Add(@(
                [string]$L.kindNoBranch, $slip, $bcd, $pcd,
                [string]$L.noBranchText, $amount))
        }

        if ($hasBranch) {
            if ($isReturn) {
                $matrix[$bcd][$cat] = $matrix[$bcd][$cat] - $amount
                $branchReturn[$bcd] = $branchReturn[$bcd] + $amount
                $returnAmount += $amount
                $returnCount++
            } else {
                $matrix[$bcd][$cat] = $matrix[$bcd][$cat] + $amount
                $branchSale[$bcd] = $branchSale[$bcd] + $amount
                $saleAmount += $amount
                $saleCount++
                if ($amount -ge $largeAmount) {
                    $largeCount++
                    [void]$expectedChecks.Add(@(
                        [string]$L.kindLarge, $slip, $bcd, $pcd,
                        [string]$L.largeText, $amount))
                }
            }
        }

        # judgement written into the detail sheet
        if ($isReturn) {
            $judge = [string]$L.judgeReturn
        } elseif ($amount -ge $largeAmount) {
            $judge = [string]$L.judgeLarge
        } elseif ($amount -gt 0) {
            $judge = [string]$L.judgeNormal
        } else {
            $judge = [string]$L.judgeCheck
        }
        if ($judgeCounts.ContainsKey($judge)) {
            $judgeCounts[$judge] = $judgeCounts[$judge] + 1
        } else {
            $judgeCounts[$judge] = 1
        }

        # ranking, which the report builds for every in-month row
        if (-not $rankAmount.ContainsKey($pcd)) {
            [void]$rankCodes.Add($pcd)
            $rankAmount[$pcd] = [double]0
            $rankQty[$pcd] = [double]0
            $rankName[$pcd] = [string]$L.unknownProductName
            $rankCat[$pcd] = [string]$L.uncategorized
        }
        if ($isReturn) {
            $rankAmount[$pcd] = $rankAmount[$pcd] - $amount
            $rankQty[$pcd] = $rankQty[$pcd] - $qty
        } else {
            $rankAmount[$pcd] = $rankAmount[$pcd] + $amount
            $rankQty[$pcd] = $rankQty[$pcd] + $qty
        }
    }

    # Duplicate slip numbers are detected after the main loop, so their
    # exception rows come after every row-driven one.
    for ($i = 0; $i -lt $inMonthRows.Count; $i++) {
        for ($j = 0; $j -lt $i; $j++) {
            if ($inMonthRows[$j].Slip -eq $inMonthRows[$i].Slip) {
                [void]$expectedChecks.Add(@(
                    [string]$L.kindDuplicate, $inMonthRows[$i].Slip,
                    $inMonthRows[$i].Branch, $inMonthRows[$i].Product,
                    [string]$L.duplicateText, $inMonthRows[$i].Amount))
                break
            }
        }
    }

    # Replay the macro's own swap sort so ties resolve identically.
    $order = @($rankCodes)
    for ($i = 0; $i -lt $order.Count - 1; $i++) {
        for ($j = $i + 1; $j -lt $order.Count; $j++) {
            if ($rankAmount[$order[$j]] -gt $rankAmount[$order[$i]]) {
                $swap = $order[$i]
                $order[$i] = $order[$j]
                $order[$j] = $swap
            }
        }
    }

    $netAmount = $saleAmount - $returnAmount
    $checkCount = $expectedChecks.Count

    # --------------------------------------------------------------
    # 2. Run the macro
    # --------------------------------------------------------------
    # Deliberately non-default application state on entry. The macro is
    # expected to put all of it back exactly as it found it. A rewrite
    # that ends with a hardcoded "ScreenUpdating = True / Calculation =
    # xlCalculationAutomatic" instead of restoring will fail here, and so
    # will one that switches these off when they were already off and
    # then forgets which way round they were.
    $xlCalculationManual = -4135
    $excel.Calculation = $xlCalculationManual
    $excel.ScreenUpdating = $false
    $excel.EnableEvents = $true
    $excel.StatusBar = $false

    $qualified = ("'" + $wb.Name.Replace("'", "''") + "'!" + $MacroName)
    [void]$excel.Run($qualified)

    Assert-Equal 'Application.Calculation restored' $xlCalculationManual `
        ([int]$excel.Calculation)
    Assert-True (-not $excel.ScreenUpdating) `
        'Application.ScreenUpdating was not restored to False.'
    Assert-True ([bool]$excel.EnableEvents) `
        'Application.EnableEvents was not restored to True.'
    # A cleared status bar comes back over COM as the string "FALSE",
    # not as a boolean, so compare loosely.
    $statusBar = $excel.StatusBar
    $statusCleared = ($null -eq $statusBar) -or
        (($statusBar -is [bool]) -and (-not $statusBar)) -or
        ([string]$statusBar -match '^(?i:false)$')
    Assert-True $statusCleared `
        ('Application.StatusBar was not handed back to Excel: [' +
         [string]$statusBar + ']')
    Assert-True (-not $excel.CutCopyMode) `
        'The clipboard was left in copy mode.'

    # The pasted cover formula only evaluates once something calculates,
    # and the entry state above is manual on purpose.
    $excel.Calculate()

    # --------------------------------------------------------------
    # 3. Read the outputs and compare
    # --------------------------------------------------------------
    $nb = $branchCodes.Count
    $totalRow = 6 + $nb
    $blockRow = $totalRow + 2

    Assert-Equal 'summary!A1' ([string]$L.summaryTitle) `
        ($wsSummary.Cells(1, 1).Value2)
    Assert-Equal 'summary!A2' ([string]$L.targetMonth) `
        ($wsSummary.Cells(2, 1).Value2)
    Assert-Equal 'summary!B2' ([string]$L.targetMonthText) `
        ($wsSummary.Cells(2, 2).Value2)
    Assert-Equal 'summary!A3' ([string]$L.createdAt) `
        ($wsSummary.Cells(3, 1).Value2)
    Assert-True (-not [string]::IsNullOrEmpty(
        [string]$wsSummary.Cells(3, 2).Value2)) `
        'summary!B3 (created at) must not be empty.'

    Add-Print 'summary.title' ($wsSummary.Cells(1, 1).Value2)
    Add-Print 'summary.targetMonth' ($wsSummary.Cells(2, 2).Value2)

    Assert-Equal 'summary!A5' ([string]$L.branchCode) `
        ($wsSummary.Cells(5, 1).Value2)
    Assert-Equal 'summary!B5' ([string]$L.branchName) `
        ($wsSummary.Cells(5, 2).Value2)
    for ($j = 0; $j -lt $categories.Count; $j++) {
        Assert-Equal ('summary header col ' + (3 + $j)) $categories[$j] `
            ($wsSummary.Cells(5, 3 + $j).Value2)
        Add-Print ('summary.header.' + (3 + $j)) `
            ($wsSummary.Cells(5, 3 + $j).Value2)
    }
    Assert-Equal 'summary total header' ([string]$L.total) `
        ($wsSummary.Cells(5, 8).Value2)

    $grandTotal = [double]0
    for ($i = 0; $i -lt $nb; $i++) {
        $row = 6 + $i
        $code = $branchCodes[$i]
        Assert-Equal ('summary row ' + $row + ' code') $code `
            ($wsSummary.Cells($row, 1).Value2)
        Assert-Equal ('summary row ' + $row + ' name') $branchName[$code] `
            ($wsSummary.Cells($row, 2).Value2)
        $rowTotal = [double]0
        for ($j = 0; $j -lt $categories.Count; $j++) {
            $cat = $categories[$j]
            $expected = $matrix[$code][$cat]
            $rowTotal += $expected
            Assert-Equal ('summary ' + $code + ' / ' + $cat) $expected `
                ([double]$wsSummary.Cells($row, 3 + $j).Value2)
            Add-Print ('summary.' + $code + '.' + $cat) $expected
        }
        Assert-Equal ('summary ' + $code + ' row total') $rowTotal `
            ([double]$wsSummary.Cells($row, 8).Value2)
        Add-Print ('summary.' + $code + '.total') $rowTotal
        $grandTotal += $rowTotal
    }

    Assert-Equal 'summary total label' ([string]$L.total) `
        ($wsSummary.Cells($totalRow, 1).Value2)
    for ($j = 0; $j -lt $categories.Count; $j++) {
        $colTotal = [double]0
        foreach ($code in $branchCodes) {
            $colTotal += $matrix[$code][$categories[$j]]
        }
        Assert-Equal ('summary column total ' + $categories[$j]) $colTotal `
            ([double]$wsSummary.Cells($totalRow, 3 + $j).Value2)
        Add-Print ('summary.total.' + $categories[$j]) $colTotal
    }
    Assert-Equal 'summary grand total' $grandTotal `
        ([double]$wsSummary.Cells($totalRow, 8).Value2)
    Add-Print 'summary.grandTotal' $grandTotal
    Assert-Equal 'summary grand total equals net' $netAmount $grandTotal

    # summary counts block
    $blockPairs = @(
        @([string]$L.summaryBlock, $null),
        @([string]$L.saleCount, $saleCount),
        @([string]$L.returnCount, $returnCount),
        @([string]$L.saleAmount, $saleAmount),
        @([string]$L.returnAmount, $returnAmount),
        @([string]$L.netAmount, $netAmount),
        @([string]$L.outOfScope, $outOfScope),
        @([string]$L.noMaster, $noMasterCount),
        @([string]$L.checkCount, $checkCount)
    )
    for ($i = 0; $i -lt $blockPairs.Count; $i++) {
        $row = $blockRow + $i
        Assert-Equal ('summary block label row ' + $row) $blockPairs[$i][0] `
            ($wsSummary.Cells($row, 1).Value2)
        if ($null -ne $blockPairs[$i][1]) {
            Assert-Equal ('summary block ' + $blockPairs[$i][0]) `
                $blockPairs[$i][1] ([double]$wsSummary.Cells($row, 2).Value2)
            Add-Print ('summary.block.' + $blockPairs[$i][0]) $blockPairs[$i][1]
        }
    }

    # presentation: header fill, total row bold, money format
    Add-Print 'summary.headerColor' ([double]$wsSummary.Cells(5, 1).Interior.Color)
    Add-Print 'summary.totalRowBold' ([bool]$wsSummary.Cells($totalRow, 1).Font.Bold)
    Add-Print 'summary.moneyFormat' ([string]$wsSummary.Cells(6, 3).NumberFormatLocal)
    Assert-True ([bool]$wsSummary.Cells($totalRow, 1).Font.Bold) `
        'The summary total row must stay bold.'
    Assert-True ([bool]$wsSummary.Cells(5, 1).Font.Bold) `
        'The summary header row must stay bold.'

    # --------------------------------------------------------------
    # branch report
    # --------------------------------------------------------------
    $hdr = 4
    $first = 5
    $sumRow = 5 + $nb
    $rankTitleRow = 7 + $nb
    $rankHeaderRow = 8 + $nb

    Assert-Equal 'report!A1' ([string]$L.reportTitle) `
        ($wsReport.Cells(1, 1).Value2)
    Assert-Equal 'report!B2' ([string]$L.targetMonthText) `
        ($wsReport.Cells(2, 2).Value2)

    $reportHeaders = @(
        [string]$L.branchCode, [string]$L.branchName, [string]$L.area,
        [string]$L.saleAmount, [string]$L.returnAmount, [string]$L.netAmount,
        [string]$L.monthTarget, [string]$L.rate, [string]$L.judge)
    for ($j = 0; $j -lt $reportHeaders.Count; $j++) {
        Assert-Equal ('report header col ' + ($j + 1)) $reportHeaders[$j] `
            ($wsReport.Cells($hdr, $j + 1).Value2)
    }

    $totalSale = [double]0
    $totalReturn = [double]0
    $totalTarget = [double]0
    for ($i = 0; $i -lt $nb; $i++) {
        $row = $first + $i
        $code = $branchCodes[$i]
        $sale = $branchSale[$code]
        $ret = $branchReturn[$code]
        $net = $sale - $ret
        $target = $branchTarget[$code]
        $rate = 0
        if ($target -ne 0) {
            $rate = $net / $target
        }
        if ($rate -ge 1) {
            $band = [string]$L.bandAchieved
        } elseif ($rate -ge 0.9) {
            $band = [string]$L.bandClose
        } elseif ($rate -ge 0.7) {
            $band = [string]$L.bandShort
        } else {
            $band = [string]$L.bandBad
        }

        Assert-Equal ('report ' + $code + ' code') $code `
            ($wsReport.Cells($row, 1).Value2)
        Assert-Equal ('report ' + $code + ' name') $branchName[$code] `
            ($wsReport.Cells($row, 2).Value2)
        Assert-Equal ('report ' + $code + ' area') $branchArea[$code] `
            ($wsReport.Cells($row, 3).Value2)
        Assert-Equal ('report ' + $code + ' sale') $sale `
            ([double]$wsReport.Cells($row, 4).Value2)
        Assert-Equal ('report ' + $code + ' return') $ret `
            ([double]$wsReport.Cells($row, 5).Value2)
        Assert-Equal ('report ' + $code + ' net') $net `
            ([double]$wsReport.Cells($row, 6).Value2)
        Assert-Equal ('report ' + $code + ' target') $target `
            ([double]$wsReport.Cells($row, 7).Value2)
        Assert-Equal ('report ' + $code + ' rate') $rate `
            ([double]$wsReport.Cells($row, 8).Value2)
        Assert-Equal ('report ' + $code + ' judgement') $band `
            ($wsReport.Cells($row, 9).Value2)

        Add-Print ('report.' + $code + '.sale') $sale
        Add-Print ('report.' + $code + '.return') $ret
        Add-Print ('report.' + $code + '.net') $net
        Add-Print ('report.' + $code + '.target') $target
        Add-Print ('report.' + $code + '.rate') $rate
        Add-Print ('report.' + $code + '.judge') `
            ($wsReport.Cells($row, 9).Value2)
        Add-Print ('report.' + $code + '.judgeColor') `
            ([double]$wsReport.Cells($row, 9).Interior.Color)
        Add-Print ('report.' + $code + '.rateFormat') `
            ([string]$wsReport.Cells($row, 8).NumberFormatLocal)

        $totalSale += $sale
        $totalReturn += $ret
        $totalTarget += $target
    }

    # the branch report re-aggregates independently: it must still agree
    Assert-Equal 'report total sale matches summary' $saleAmount $totalSale
    Assert-Equal 'report total return matches summary' $returnAmount $totalReturn
    Assert-Equal 'report total sale cell' $totalSale `
        ([double]$wsReport.Cells($sumRow, 4).Value2)
    Assert-Equal 'report total return cell' $totalReturn `
        ([double]$wsReport.Cells($sumRow, 5).Value2)
    Assert-Equal 'report total net cell' ($totalSale - $totalReturn) `
        ([double]$wsReport.Cells($sumRow, 6).Value2)
    Assert-Equal 'report total target cell' $totalTarget `
        ([double]$wsReport.Cells($sumRow, 7).Value2)
    Add-Print 'report.total.net' ($totalSale - $totalReturn)
    Add-Print 'report.total.judge' ($wsReport.Cells($sumRow, 9).Value2)

    # ranking
    Assert-Equal 'report rank title' ([string]$L.rankTitle) `
        ($wsReport.Cells($rankTitleRow, 1).Value2)
    $rankHeaders = @(
        [string]$L.rank, [string]$L.productCode, [string]$L.productName,
        [string]$L.category, [string]$L.rankAmount, [string]$L.quantity)
    for ($j = 0; $j -lt $rankHeaders.Count; $j++) {
        Assert-Equal ('report rank header col ' + ($j + 1)) $rankHeaders[$j] `
            ($wsReport.Cells($rankHeaderRow, $j + 1).Value2)
    }
    for ($i = 1; $i -le 5; $i++) {
        $row = $rankHeaderRow + $i
        $code = $order[$i - 1]
        Assert-Equal ('rank ' + $i + ' position') $i `
            ([double]$wsReport.Cells($row, 1).Value2)
        Assert-Equal ('rank ' + $i + ' code') $code `
            ($wsReport.Cells($row, 2).Value2)
        Assert-Equal ('rank ' + $i + ' name') $rankName[$code] `
            ($wsReport.Cells($row, 3).Value2)
        Assert-Equal ('rank ' + $i + ' category') $rankCat[$code] `
            ($wsReport.Cells($row, 4).Value2)
        Assert-Equal ('rank ' + $i + ' amount') $rankAmount[$code] `
            ([double]$wsReport.Cells($row, 5).Value2)
        Assert-Equal ('rank ' + $i + ' quantity') $rankQty[$code] `
            ([double]$wsReport.Cells($row, 6).Value2)
        Add-Print ('rank.' + $i + '.code') $code
        Add-Print ('rank.' + $i + '.amount') $rankAmount[$code]
        Add-Print ('rank.' + $i + '.qty') $rankQty[$code]
    }

    Assert-Equal 'report large-order label' ([string]$L.largeCount) `
        ($wsReport.Cells($rankHeaderRow + 7, 1).Value2)
    Assert-Equal 'report large-order count' $largeCount `
        ([double]$wsReport.Cells($rankHeaderRow + 7, 2).Value2)
    Add-Print 'report.largeCount' $largeCount

    # --------------------------------------------------------------
    # exception list
    # --------------------------------------------------------------
    $checkHeaders = @($L.checkHeaders)
    for ($j = 0; $j -lt $checkHeaders.Count; $j++) {
        Assert-Equal ('check header col ' + ($j + 1)) ([string]$checkHeaders[$j]) `
            ($wsCheck.Cells(1, $j + 1).Value2)
    }
    $checkLast = $wsCheck.Cells($wsCheck.Rows.Count, 1).End(-4162).Row
    Assert-Equal 'check row count' ($checkCount + 1) $checkLast
    Add-Print 'check.count' $checkCount

    for ($i = 0; $i -lt $expectedChecks.Count; $i++) {
        $row = $i + 2
        $exp = $expectedChecks[$i]
        Assert-Equal ('check row ' + $row + ' kind') $exp[0] `
            ($wsCheck.Cells($row, 1).Value2)
        Assert-Equal ('check row ' + $row + ' slip') $exp[1] `
            ($wsCheck.Cells($row, 2).Value2)
        Assert-Equal ('check row ' + $row + ' branch') $exp[2] `
            ($wsCheck.Cells($row, 3).Value2)
        Assert-Equal ('check row ' + $row + ' product') $exp[3] `
            ($wsCheck.Cells($row, 4).Value2)
        Assert-Equal ('check row ' + $row + ' text') $exp[4] `
            ($wsCheck.Cells($row, 5).Value2)
        Assert-Equal ('check row ' + $row + ' amount') $exp[5] `
            ([double]$wsCheck.Cells($row, 6).Value2)
    }
    Add-Print 'check.firstKind' ($wsCheck.Cells(2, 1).Value2)
    Add-Print 'check.lastSlip' ($wsCheck.Cells($checkLast, 2).Value2)

    $duplicateRows = @($expectedChecks | Where-Object {
        $_[0] -eq [string]$L.kindDuplicate
    })
    Assert-True ($duplicateRows.Count -ge 2) `
        ('The sample must contain re-keyed slips to find, expected at ' +
         'least 2, oracle found ' + $duplicateRows.Count + '.')
    Add-Print 'check.duplicates' $duplicateRows.Count

    # --------------------------------------------------------------
    # staff summary: written in first-appearance order, with a running
    # total that only makes sense in that order
    # --------------------------------------------------------------
    Assert-Equal 'staff!A1' ([string]$L.staffTitle) `
        ($wsStaff.Cells(1, 1).Value2)
    Assert-Equal 'staff!B2' ([string]$L.targetMonthText) `
        ($wsStaff.Cells(2, 2).Value2)
    $staffHeaders = @($L.staffHeaders)
    for ($j = 0; $j -lt $staffHeaders.Count; $j++) {
        Assert-Equal ('staff header col ' + ($j + 1)) ([string]$staffHeaders[$j]) `
            ($wsStaff.Cells(4, $j + 1).Value2)
    }

    $running = [double]0
    $staffTotalCount = 0
    $staffTotalSale = [double]0
    $staffTotalReturn = [double]0
    for ($i = 0; $i -lt $staffOrder.Count; $i++) {
        $row = 5 + $i
        $person = $staffOrder[$i]
        $net = $staffSale[$person] - $staffReturn[$person]
        $running += $net
        Assert-Equal ('staff row ' + $row + ' sequence') ($i + 1) `
            ([double]$wsStaff.Cells($row, 1).Value2)
        Assert-Equal ('staff row ' + $row + ' name') $person `
            ($wsStaff.Cells($row, 2).Value2)
        Assert-Equal ('staff ' + $person + ' count') $staffCount[$person] `
            ([double]$wsStaff.Cells($row, 3).Value2)
        Assert-Equal ('staff ' + $person + ' sale') $staffSale[$person] `
            ([double]$wsStaff.Cells($row, 4).Value2)
        Assert-Equal ('staff ' + $person + ' return') $staffReturn[$person] `
            ([double]$wsStaff.Cells($row, 5).Value2)
        Assert-Equal ('staff ' + $person + ' net') $net `
            ([double]$wsStaff.Cells($row, 6).Value2)
        Assert-Equal ('staff ' + $person + ' running total') $running `
            ([double]$wsStaff.Cells($row, 7).Value2)
        Add-Print ('staff.' + ($i + 1) + '.name') $person
        Add-Print ('staff.' + ($i + 1) + '.net') $net
        Add-Print ('staff.' + ($i + 1) + '.running') $running
        $staffTotalCount += $staffCount[$person]
        $staffTotalSale += $staffSale[$person]
        $staffTotalReturn += $staffReturn[$person]
    }
    $staffTotalRow = 5 + $staffOrder.Count
    Assert-Equal 'staff total label' ([string]$L.total) `
        ($wsStaff.Cells($staffTotalRow, 2).Value2)
    Assert-Equal 'staff total count' $staffTotalCount `
        ([double]$wsStaff.Cells($staffTotalRow, 3).Value2)
    Assert-Equal 'staff total net' ($staffTotalSale - $staffTotalReturn) `
        ([double]$wsStaff.Cells($staffTotalRow, 6).Value2)
    # Every in-month row belongs to exactly one person, including the
    # rows whose branch is missing from the master.
    Assert-Equal 'staff total count matches detail' $inMonthRows.Count `
        $staffTotalCount
    Add-Print 'staff.rows' $staffOrder.Count
    Add-Print 'staff.total.net' ($staffTotalSale - $staffTotalReturn)

    # --------------------------------------------------------------
    # cover sheet: pasted from the template, so formatting and the live
    # formula have to survive. Replacing the Copy with a value
    # assignment loses all four of the checks below.
    # --------------------------------------------------------------
    Assert-Equal 'cover!A1' ([string]$L.coverTitle) `
        ($wsCover.Cells(1, 1).Value2)
    Assert-Equal 'cover!A3' ([string]$L.coverDeptLabel) `
        ($wsCover.Cells(3, 1).Value2)
    Assert-Equal 'cover!B3' ([string]$L.coverDeptValue) `
        ($wsCover.Cells(3, 2).Value2)
    Assert-Equal 'cover!A5' ([string]$L.coverNetLabel) `
        ($wsCover.Cells(5, 1).Value2)
    Assert-Equal 'cover!A6' ([string]$L.coverNoteLabel) `
        ($wsCover.Cells(6, 1).Value2)
    Assert-Equal 'cover!B6' ([string]$L.coverNoteValue) `
        ($wsCover.Cells(6, 2).Value2)

    Assert-Equal 'cover formula survived the paste' `
        ([string]$data.template.formula) ([string]$wsCover.Cells(5, 2).Formula)
    Assert-Equal 'cover formula result' $grandTotal `
        ([double]$wsCover.Cells(5, 2).Value2)
    Assert-Equal 'cover number format survived the paste' `
        ([string]$wsTemplate.Range('B5').NumberFormatLocal) `
        ([string]$wsCover.Cells(5, 2).NumberFormatLocal)
    Assert-Equal 'cover title fill survived the paste' `
        ([double]$wsTemplate.Range('A1').Interior.Color) `
        ([double]$wsCover.Cells(1, 1).Interior.Color)
    Assert-Equal 'cover title size survived the paste' `
        ([double]$wsTemplate.Range('A1').Font.Size) `
        ([double]$wsCover.Cells(1, 1).Font.Size)
    Add-Print 'cover.formula' ([string]$wsCover.Cells(5, 2).Formula)
    Add-Print 'cover.formulaValue' ([double]$wsCover.Cells(5, 2).Value2)
    Add-Print 'cover.numberFormat' `
        ([string]$wsCover.Cells(5, 2).NumberFormatLocal)
    Add-Print 'cover.titleColor' ([double]$wsCover.Cells(1, 1).Interior.Color)
    Add-Print 'cover.titleSize' ([double]$wsCover.Cells(1, 1).Font.Size)

    # values-only block copied off the branch report
    Assert-Equal 'cover!A9' ([string]$L.coverBranchTotalLabel) `
        ($wsCover.Cells(9, 1).Value2)
    Assert-Equal 'cover branch sale' $totalSale `
        ([double]$wsCover.Cells(9, 2).Value2)
    Assert-Equal 'cover branch return' $totalReturn `
        ([double]$wsCover.Cells(9, 3).Value2)
    Assert-Equal 'cover branch net' ($totalSale - $totalReturn) `
        ([double]$wsCover.Cells(9, 4).Value2)
    Assert-Equal 'cover branch target' $totalTarget `
        ([double]$wsCover.Cells(9, 5).Value2)

    # This one is a displayed string, taken from .Text on a formatted
    # cell. Swapping that read for .Value2 changes it to raw digits.
    Assert-Equal 'cover!A11' ([string]$L.coverTargetLabel) `
        ($wsCover.Cells(11, 1).Value2)
    $expectedTargetText = $totalTarget.ToString(
        '#,##0', [Globalization.CultureInfo]::InvariantCulture)
    Assert-Equal 'cover target display string' $expectedTargetText `
        ([string]$wsCover.Cells(11, 2).Value2)
    Add-Print 'cover.targetText' ([string]$wsCover.Cells(11, 2).Value2)

    # the completion message the operator reads
    Assert-Equal 'cover!A13' ([string]$L.coverResultLabel) `
        ($wsCover.Cells(13, 1).Value2)
    $expectedMessage = ([string]$L.messagePrefix + $checkCount +
        [string]$L.messageSuffix)
    Assert-Equal 'cover result message' $expectedMessage `
        ([string]$wsCover.Cells(13, 2).Value2)
    Add-Print 'cover.message' ([string]$wsCover.Cells(13, 2).Value2)

    # the template must be left alone
    Assert-Equal 'template formula untouched' `
        ([string]$data.template.formula) `
        ([string]$wsTemplate.Range('B5').Formula)
    Assert-True ($wsTemplate.Visible -ne -1) `
        'The template sheet must stay hidden.'

    # --------------------------------------------------------------
    # detail judgement column
    # --------------------------------------------------------------
    $afterDetail = Read-Grid $wsDetail $detailRows 9
    $actualJudge = @{}
    $actualBlank = 0
    for ($i = 2; $i -le $detailRows; $i++) {
        $value = [string](Get-Cell $afterDetail $i 9)
        if ([string]::IsNullOrEmpty($value)) {
            $actualBlank++
        } else {
            if ($actualJudge.ContainsKey($value)) {
                $actualJudge[$value] = $actualJudge[$value] + 1
            } else {
                $actualJudge[$value] = 1
            }
        }
    }
    Assert-Equal 'detail rows with no judgement' $outOfScope $actualBlank
    foreach ($key in @($judgeCounts.Keys | Sort-Object)) {
        Assert-Equal ('detail judgement count ' + $key) $judgeCounts[$key] `
            $actualJudge[$key]
        Add-Print ('detail.judge.' + $key) $judgeCounts[$key]
    }
    Assert-Equal 'detail judgement kinds' $judgeCounts.Keys.Count `
        $actualJudge.Keys.Count
    Add-Print 'detail.rows' ($detailRows - 1)
    Add-Print 'detail.blankJudge' $actualBlank

    # --------------------------------------------------------------
    # 4. Idempotence: a second run must not move anything
    # --------------------------------------------------------------
    $firstPass = @{}
    foreach ($key in $script:Print.Keys) {
        $firstPass[$key] = $script:Print[$key]
    }

    [void]$excel.Run($qualified)

    $moved = New-Object System.Collections.ArrayList
    foreach ($i in 0..($nb - 1)) {
        $code = $branchCodes[$i]
        $row = $first + $i
        if ((Format-Value ([double]$wsReport.Cells($row, 6).Value2)) -ne
            $firstPass['report.' + $code + '.net']) {
            [void]$moved.Add('report.' + $code + '.net')
        }
        $summaryRow = 6 + $i
        if ((Format-Value ([double]$wsSummary.Cells($summaryRow, 8).Value2)) -ne
            $firstPass['summary.' + $code + '.total']) {
            [void]$moved.Add('summary.' + $code + '.total')
        }
    }
    if ((Format-Value ([double]$wsSummary.Cells($totalRow, 8).Value2)) -ne
        $firstPass['summary.grandTotal']) {
        [void]$moved.Add('summary.grandTotal')
    }
    $checkLast2 = $wsCheck.Cells($wsCheck.Rows.Count, 1).End(-4162).Row
    if ($checkLast2 -ne $checkLast) {
        [void]$moved.Add('check.count')
    }
    Assert-True ($moved.Count -eq 0) `
        ('A second run changed: ' + ($moved -join ', '))

    # --------------------------------------------------------------
    # 5. Golden fingerprint
    # --------------------------------------------------------------
    if ($WriteExpected) {
        $ordered = New-Object System.Collections.Specialized.OrderedDictionary
        foreach ($key in $script:Print.Keys) {
            $ordered[$key] = $script:Print[$key]
        }
        $json = $ordered | ConvertTo-Json -Depth 4
        [IO.File]::WriteAllText($expectedPath, $json,
            (New-Object Text.UTF8Encoding($false)))
        Write-Output ('Wrote golden fingerprint: ' + $expectedPath)
    } else {
        if (-not [IO.File]::Exists($expectedPath)) {
            throw ('Missing golden fingerprint. Run with -WriteExpected: ' +
                $expectedPath)
        }
        $expected = [IO.File]::ReadAllText($expectedPath,
            [Text.Encoding]::UTF8) | ConvertFrom-Json
        $expectedKeys = @($expected.PSObject.Properties.Name)
        Assert-Equal 'golden fingerprint size' $expectedKeys.Count `
            $script:Print.Count
        foreach ($key in $expectedKeys) {
            $want = [string]$expected.$key
            $got = [string]$script:Print[$key]
            $script:Checks++
            if ($want -ne $got) {
                Add-Failure ('golden ' + $key + ': expected [' + $want +
                    '], got [' + $got + ']')
            }
        }
    }

    if ($ShowFingerprint) {
        foreach ($key in $script:Print.Keys) {
            Write-Output ('  ' + $key + ' = ' + $script:Print[$key])
        }
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

    Assert-InsideDirectory $copyPath $testdataRoot
    if ([IO.File]::Exists($copyPath)) {
        [IO.File]::Delete($copyPath)
    }
}

if ($script:Failures.Count -gt 0) {
    Write-Output 'test-monthly-report-equivalence: FAIL'
    Write-Output ('checks=' + $script:Checks +
        ', failures=' + $script:Failures.Count)
    foreach ($failure in $script:Failures) {
        Write-Output ('  - ' + $failure)
    }
    exit 1
}

Write-Output 'test-monthly-report-equivalence: PASS'
Write-Output ('book=' + [IO.Path]::GetFileName($resolvedBook) +
    ', macro=' + $MacroName)
Write-Output ('checks=' + $script:Checks +
    ', fingerprint=' + $script:Print.Count + ' values')
