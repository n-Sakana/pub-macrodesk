Option Explicit

'============================================================
' 月次売上集計マクロ  本体
'
' 毎月 5 営業日目に、売上明細から月次集計表と支店別レポートを
' 作ります。担当が変わるたびに継ぎ足してきたので、この Sub が
' だんだん長くなりました。
'
' 使い方: 設定シートの「対象年月」を直してから
'         RunMonthlyReport を実行してください。
'============================================================

Public Sub RunMonthlyReport()
    Dim ws As Worksheet
    Dim ws2 As Worksheet
    Dim ws3 As Worksheet
    Dim wsM As Worksheet
    Dim wsB As Worksheet
    Dim dat As Variant
    Dim mat() As Double
    Dim cnt() As Long
    Dim bUri() As Double
    Dim bHen() As Double
    Dim bCode() As String
    Dim bName() As String
    Dim cats As Variant
    Dim i As Long, j As Long, k As Long
    Dim n As Long, nb As Long
    Dim r As Long, c As Long
    Dim bi As Long, ci As Long
    Dim pr As Long, br As Long
    Dim qty As Double, tanka As Double, kingaku As Double
    Dim uriCnt As Long, henCnt As Long
    Dim denpyo As String, bcd As String, pcd As String
    Dim kubun As String, bunrui As String, hantei As String
    Dim v As Variant
    Dim tmp As Double
    Dim oldCalc As XlCalculation
    Dim oldUpd As Boolean
    Dim oldEvt As Boolean
    Dim saved As Boolean

    ' --- 準備 ---------------------------------------------
    InitGlobals
    oldCalc = Application.Calculation
    oldUpd = Application.ScreenUpdating
    oldEvt = Application.EnableEvents
    saved = True
    Application.Calculation = xlCalculationManual
    Application.ScreenUpdating = False
    Application.EnableEvents = False
    Application.StatusBar = "月次集計を作成しています..."

    ' このあと少し行儀の悪い書き方が続くので、まとめて逃がしています。
    On Error Resume Next

    ' --- 設定の読み込み -----------------------------------
    g_TargetYm = Txt(GetSetteiValue("対象年月"))
    g_LargeAmount = Num(GetSetteiValue("大口判定金額"))
    If g_TargetYm = "" Then
        g_TargetYm = "202606"
    End If
    g_Ready = True

    Set ws = ThisWorkbook.Worksheets("売上明細")
    Set wsM = ThisWorkbook.Worksheets("商品マスタ")
    Set wsB = ThisWorkbook.Worksheets("支店マスタ")
    Set ws2 = ThisWorkbook.Worksheets("月次集計")
    Set ws3 = ThisWorkbook.Worksheets("点検リスト")

    ' --- 出力シートの初期化 -------------------------------
    ClearOutputArea ws2
    ClearOutputArea ws3
    ClearOutputArea ThisWorkbook.Worksheets("支店別レポート")

    ws3.Cells(1, 1).Value = "種別"
    ws3.Cells(1, 2).Value = "伝票番号"
    ws3.Cells(1, 3).Value = "支店コード"
    ws3.Cells(1, 4).Value = "商品コード"
    ws3.Cells(1, 5).Value = "内容"
    ws3.Cells(1, 6).Value = "金額"
    SetCheckHeader ws3
    g_CheckRow = 1

    ' --- 支店の一覧を作る ---------------------------------
    nb = LastRow1(wsB) - 1
    ReDim bCode(1 To nb)
    ReDim bName(1 To nb)
    For i = 1 To nb
        bCode(i) = Txt(wsB.Cells(i + 1, 1).Value)
        bName(i) = Txt(wsB.Cells(i + 1, 2).Value)
    Next i

    cats = CategoryList()
    ReDim mat(1 To nb, 1 To 5)
    ReDim cnt(1 To nb, 1 To 5)
    ReDim bUri(1 To nb)
    ReDim bHen(1 To nb)

    ' --- 明細を配列で受けておく ---------------------------
    ' 速くなると聞いたので入れましたが、下では結局セルも見ています。
    n = LastRow2(ws, 1)
    dat = ws.Range(ws.Cells(1, 1), ws.Cells(n, 9)).Value

    ' --- 明細ループ ---------------------------------------
    uriCnt = 0
    henCnt = 0
    For i = 2 To n
        If i Mod 25 = 0 Then
            Application.StatusBar = "明細を集計しています... " & i & "/" & n
        End If

        denpyo = Txt(dat(i, 1))
        bcd = Txt(dat(i, 3))
        pcd = Txt(dat(i, 4))
        qty = Num(dat(i, 5))
        tanka = Num(dat(i, 6))
        kubun = Txt(dat(i, 7))
        kingaku = qty * tanka

        If IsTargetMonth(ws.Cells(i, 2).Value) = False Then
            g_SkipCount = g_SkipCount + 1
            ws.Cells(i, 9).Value = ""
            ws.Cells(i, 9).Interior.ColorIndex = xlNone
        Else
            ' 商品マスタ引き当て
            pr = FindProductRow(pcd)
            If pr = 0 Then
                bunrui = "未分類"
                g_NoMasterCount = g_NoMasterCount + 1
                AddCheck "マスタ未登録", denpyo, bcd, pcd, _
                         "商品マスタに商品コードがありません", kingaku
            Else
                bunrui = Txt(wsM.Cells(pr, 3).Value)
                If bunrui = "" Then
                    bunrui = "未分類"
                End If
            End If

            ' 支店マスタ引き当て
            br = FindBranchRow(bcd)
            If br = 0 Then
                AddCheck "支店未登録", denpyo, bcd, pcd, _
                         "支店マスタに支店コードがありません", kingaku
                bi = 0
            Else
                bi = br - 1
            End If

            ci = CategoryIndex(bunrui)

            If bi > 0 Then
                If IsHenpin(kubun) = True Then
                    mat(bi, ci) = mat(bi, ci) - kingaku
                    cnt(bi, ci) = cnt(bi, ci) + 1
                    bHen(bi) = bHen(bi) + kingaku
                    g_TotalHen = g_TotalHen + kingaku
                    henCnt = henCnt + 1
                Else
                    mat(bi, ci) = mat(bi, ci) + kingaku
                    cnt(bi, ci) = cnt(bi, ci) + 1
                    bUri(bi) = bUri(bi) + kingaku
                    g_TotalUri = g_TotalUri + kingaku
                    uriCnt = uriCnt + 1
                    If IsOoguchi(kingaku) = True Then
                        AddCheck "大口", denpyo, bcd, pcd, _
                                 "大口判定金額以上の売上です", kingaku
                    End If
                End If
            End If

            hantei = JudgeMeisai(kubun, kingaku)
            ws.Cells(i, 9).Value = hantei
            PaintHantei ws, i, 9, hantei
        End If
    Next i

    On Error GoTo 0

    ' --- 担当者別と伝票の重複チェック ---------------------
    ' 点検件数を数える前に済ませておく必要があります。
    Application.StatusBar = "担当者別を集計しています..."
    BuildStaffSummary

    ' --- 月次集計シートの書き出し -------------------------
    ws2.Cells(1, 1).Value = "月次売上集計表"
    ' ここを文字列にしておかないと「2026年06月」が日付になってしまいます。
    ws2.Range("B2:B3").NumberFormatLocal = "@"
    ws2.Cells(2, 1).Value = "対象年月"
    ws2.Cells(2, 2).Value = Left(g_TargetYm, 4) & "年" & Right(g_TargetYm, 2) & "月"
    ws2.Cells(3, 1).Value = "作成日時"
    ws2.Cells(3, 2).Value = Format(Now, "yyyy/mm/dd hh:nn:ss")

    ws2.Cells(5, 1).Value = "支店コード"
    ws2.Cells(5, 2).Value = "支店名"
    For j = 0 To UBound(cats)
        ws2.Cells(5, 3 + j).Value = cats(j)
    Next j
    ws2.Cells(5, 8).Value = "合計"

    For i = 1 To nb
        r = 5 + i
        ws2.Cells(r, 1).Value = bCode(i)
        ws2.Cells(r, 2).Value = bName(i)
        tmp = 0
        For j = 1 To 5
            ws2.Cells(r, 2 + j).Value = mat(i, j)
            tmp = tmp + mat(i, j)
        Next j
        ws2.Cells(r, 8).Value = tmp
    Next i

    ' 合計行。列ごとにもう一度足しています。
    r = 6 + nb
    ws2.Cells(r, 1).Value = "合計"
    ws2.Cells(r, 2).Value = ""
    For j = 1 To 5
        tmp = 0
        For i = 1 To nb
            tmp = tmp + mat(i, j)
        Next i
        ws2.Cells(r, 2 + j).Value = tmp
    Next j
    tmp = 0
    For i = 1 To nb
        For j = 1 To 5
            tmp = tmp + mat(i, j)
        Next j
    Next i
    ws2.Cells(r, 8).Value = tmp

    ' --- サマリ欄 -----------------------------------------
    ' ここだけシートを表示してから ActiveSheet で書いています。
    ws2.Activate
    k = r + 2
    ActiveSheet.Cells(k, 1).Value = "件数・金額サマリ"
    ActiveSheet.Cells(k, 1).Font.Bold = True
    ActiveSheet.Cells(k + 1, 1).Value = "売上件数"
    ActiveSheet.Cells(k + 1, 2).Value = uriCnt
    ActiveSheet.Cells(k + 2, 1).Value = "返品件数"
    ActiveSheet.Cells(k + 2, 2).Value = henCnt
    ActiveSheet.Cells(k + 3, 1).Value = "売上金額"
    ActiveSheet.Cells(k + 3, 2).Value = g_TotalUri
    ActiveSheet.Cells(k + 4, 1).Value = "返品金額"
    ActiveSheet.Cells(k + 4, 2).Value = g_TotalHen
    ActiveSheet.Cells(k + 5, 1).Value = "純売上"
    ActiveSheet.Cells(k + 5, 2).Value = g_TotalUri - g_TotalHen
    ActiveSheet.Cells(k + 6, 1).Value = "対象外件数"
    ActiveSheet.Cells(k + 6, 2).Value = g_SkipCount
    ActiveSheet.Cells(k + 7, 1).Value = "マスタ未登録件数"
    ActiveSheet.Cells(k + 7, 2).Value = g_NoMasterCount
    ActiveSheet.Cells(k + 8, 1).Value = "点検件数"
    ActiveSheet.Cells(k + 8, 2).Value = g_CheckRow - 1

    ' --- 書式 ---------------------------------------------
    ApplyHeaderFormat ws2, 5, 1, 8
    MarkTotalRow ws2, 6 + nb, 1, 8
    For i = 1 To nb + 1
        FormatMoneyColumn ws2, 3, 6, 6 + nb
    Next i
    FormatMoneyColumn ws2, 4, 6, 6 + nb
    FormatMoneyColumn ws2, 5, 6, 6 + nb
    FormatMoneyColumn ws2, 6, 6, 6 + nb
    FormatMoneyColumn ws2, 7, 6, 6 + nb
    FormatMoneyColumn ws2, 8, 6, 6 + nb
    SetMoneyFormat ws2.Range(ws2.Cells(k + 3, 2), ws2.Cells(k + 5, 2))
    SetTitleStyle ws2, "A1"
    FitColumns ws2, 1, 8

    ' --- 支店別レポート -----------------------------------
    Application.StatusBar = "支店別レポートを作成しています..."
    BuildBranchReport

    ' --- 点検リストの仕上げ -------------------------------
    FormatMoneyColumn ws3, 6, 2, g_CheckRow
    FitColumns ws3, 1, 6

    g_Message = "月次集計が終わりました。点検件数 " & (g_CheckRow - 1) & " 件。"

    ' --- 提出用の表紙 -------------------------------------
    Application.StatusBar = "報告書を作成しています..."
    BuildCoverSheet

    ' --- 後始末 -------------------------------------------
    ws2.Activate
    ws2.Range("A1").Select
    If saved = True Then
        Application.Calculation = oldCalc
        Application.ScreenUpdating = oldUpd
        Application.EnableEvents = oldEvt
    End If
    Application.StatusBar = False
End Sub

' 実行前に中身を確かめたいとき用。集計はしません。
Public Sub ShowTargetMonth()
    Dim s As String

    s = Txt(GetSetteiValue("対象年月"))
    If s = "" Then
        s = "(未設定)"
    End If
    g_Message = "対象年月: " & s
End Sub
