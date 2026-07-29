Option Explicit

'============================================================
' 月次売上集計マクロ  支店別レポート
'
' もとは別ブックで作っていたものを、2021 年にこのブックへ
' 取り込みました。そのときの作りのまま、明細をもう一度
' 頭から読み直して集計しています。
'
' 支店の行だけ CReportRow クラスに置き換えてあります（2022/03）。
' 商品側は配列のままなので、書き方が途中で変わっています。
'
' 分類の並びは SalesRules.CategoryList と同じものを
' ここにも書いてあります。
'============================================================

Public Sub BuildBranchReport()
    Dim ws As Worksheet
    Dim wsB As Worksheet
    Dim wsM As Worksheet
    Dim wsR As Worksheet
    Dim rows As Collection
    Dim rw As CReportRow
    Dim pCode() As String
    Dim pName() As String
    Dim pBun() As String
    Dim pKin() As Double
    Dim pSuu() As Double
    Dim i As Long, j As Long
    Dim n As Long, nb As Long, np As Long, nu As Long
    Dim r As Long
    Dim hdr As Long, first As Long, last As Long, sum As Long
    Dim ttl As Long, rh As Long
    Dim a As String, b As String, s As String
    Dim x As Double, y As Double
    Dim q As Double, t As Double, kin As Double
    Dim idx As Long
    Dim ooguchi As Long
    Dim ritsu As Double
    Dim hantei As String
    Dim ts As Double, th As Double
    Dim swapS As String, swapD As Double

    Set ws = ThisWorkbook.Worksheets("売上明細")
    Set wsB = ThisWorkbook.Worksheets("支店マスタ")
    Set wsM = ThisWorkbook.Worksheets("商品マスタ")
    Set wsR = ThisWorkbook.Worksheets("支店別レポート")

    ' --- 支店 ---------------------------------------------
    nb = GetLastRow(wsB) - 1
    Set rows = New Collection
    For i = 1 To nb
        Set rw = New CReportRow
        rw.Code = Txt(wsB.Cells(i + 1, 1).Value)
        rw.BranchName = Txt(wsB.Cells(i + 1, 2).Value)
        rw.Area = Txt(wsB.Cells(i + 1, 3).Value)
        rw.Target = Num(wsB.Cells(i + 1, 4).Value)
        rows.Add rw
    Next i

    ' --- 商品。マスタの分だけ先に枠を取ります ---------------
    np = GetLastRow(wsM) - 1
    ReDim pCode(1 To np + 50)
    ReDim pName(1 To np + 50)
    ReDim pBun(1 To np + 50)
    ReDim pKin(1 To np + 50)
    ReDim pSuu(1 To np + 50)
    For i = 1 To np
        pCode(i) = Txt(wsM.Cells(i + 1, 1).Value)
        pName(i) = Txt(wsM.Cells(i + 1, 2).Value)
        pBun(i) = Txt(wsM.Cells(i + 1, 3).Value)
        pKin(i) = 0
        pSuu(i) = 0
    Next i
    nu = np

    ' --- 明細をもう一度読みます ---------------------------
    n = LastRow1(ws)
    ooguchi = 0
    i = 2
    Do While i <= n
        If IsTargetMonth(ws.Cells(i, 2).Value) = True Then
            a = Txt(ws.Cells(i, 3).Value)
            b = Txt(ws.Cells(i, 4).Value)
            q = Num(ws.Cells(i, 5).Value)
            t = Num(ws.Cells(i, 6).Value)
            s = Txt(ws.Cells(i, 7).Value)
            kin = q * t

            idx = 0
            For j = 1 To rows.Count
                If rows(j).Code = a Then
                    idx = j
                    Exit For
                End If
            Next j

            If idx > 0 Then
                Set rw = rows(idx)
                If IsHenpin(s) = True Then
                    rw.AddReturn kin
                Else
                    rw.AddSale kin
                    If IsBigAmount(kin) = True Then
                        ooguchi = ooguchi + 1
                    End If
                End If
            End If

            ' 商品側。見つからなければ後ろへ足します。
            idx = 0
            For j = 1 To nu
                If pCode(j) = b Then
                    idx = j
                    Exit For
                End If
            Next j
            If idx = 0 Then
                nu = nu + 1
                pCode(nu) = b
                pName(nu) = "(マスタ未登録)"
                pBun(nu) = "未分類"
                pKin(nu) = 0
                pSuu(nu) = 0
                idx = nu
            End If
            If IsHenpin(s) = True Then
                pKin(idx) = pKin(idx) - kin
                pSuu(idx) = pSuu(idx) - q
            Else
                pKin(idx) = pKin(idx) + kin
                pSuu(idx) = pSuu(idx) + q
            End If
        End If
        i = i + 1
    Loop

    ' --- 並べ替え。単純な入れ替えです ----------------------
    For i = 1 To nu - 1
        For j = i + 1 To nu
            If pKin(j) > pKin(i) Then
                swapD = pKin(i): pKin(i) = pKin(j): pKin(j) = swapD
                swapD = pSuu(i): pSuu(i) = pSuu(j): pSuu(j) = swapD
                swapS = pCode(i): pCode(i) = pCode(j): pCode(j) = swapS
                swapS = pName(i): pName(i) = pName(j): pName(j) = swapS
                swapS = pBun(i): pBun(i) = pBun(j): pBun(j) = swapS
            End If
        Next j
    Next i

    ' --- 書き出し -----------------------------------------
    hdr = 4
    first = 5
    last = 4 + nb
    sum = 5 + nb
    ttl = 7 + nb
    rh = 8 + nb

    wsR.Cells(1, 1).Value = "支店別月次レポート"
    ' 集計表のほうと同じ理由で、ここも文字列にしています。
    wsR.Range("B2").NumberFormatLocal = "@"
    wsR.Cells(2, 1).Value = "対象年月"
    wsR.Cells(2, 2).Value = Left(g_TargetYm, 4) & "年" & Right(g_TargetYm, 2) & "月"

    wsR.Cells(hdr, 1).Value = "支店コード"
    wsR.Cells(hdr, 2).Value = "支店名"
    wsR.Cells(hdr, 3).Value = "地域"
    wsR.Cells(hdr, 4).Value = "売上金額"
    wsR.Cells(hdr, 5).Value = "返品金額"
    wsR.Cells(hdr, 6).Value = "純売上"
    wsR.Cells(hdr, 7).Value = "月次目標"
    wsR.Cells(hdr, 8).Value = "達成率"
    wsR.Cells(hdr, 9).Value = "判定"

    ts = 0
    th = 0
    For i = 1 To nb
        Set rw = rows(i)
        r = first + i - 1
        x = rw.Sale
        y = rw.ReturnAmount
        Application.StatusBar = "支店別: " & rw.Describe()
        wsR.Cells(r, 1).Value = rw.Code
        wsR.Cells(r, 2).Value = rw.BranchName
        wsR.Cells(r, 3).Value = rw.Area
        wsR.Cells(r, 4).Value = x
        wsR.Cells(r, 5).Value = y
        wsR.Cells(r, 6).Value = rw.NetAmount
        wsR.Cells(r, 7).Value = rw.Target
        ritsu = rw.Rate
        wsR.Cells(r, 8).Value = ritsu
        wsR.Cells(r, 8).NumberFormatLocal = "0.0%"
        hantei = rw.Judgement
        wsR.Cells(r, 9).Value = hantei
        PaintTassei wsR, r, 9, hantei
        ts = ts + x
        th = th + y
    Next i

    wsR.Cells(sum, 1).Value = "合計"
    wsR.Cells(sum, 4).Value = ts
    wsR.Cells(sum, 5).Value = th
    wsR.Cells(sum, 6).Value = ts - th
    x = 0
    For i = 1 To rows.Count
        x = x + rows(i).Target
    Next i
    wsR.Cells(sum, 7).Value = x
    ritsu = Tasseiritsu(ts - th, x)
    wsR.Cells(sum, 8).Value = ritsu
    wsR.Cells(sum, 8).NumberFormatLocal = "0.0%"
    wsR.Cells(sum, 9).Value = TasseiHantei(ritsu)

    ' --- 上位商品 -----------------------------------------
    wsR.Cells(ttl, 1).Value = "売上上位商品"
    wsR.Cells(ttl, 1).Font.Bold = True
    wsR.Cells(rh, 1).Value = "順位"
    wsR.Cells(rh, 2).Value = "商品コード"
    wsR.Cells(rh, 3).Value = "商品名"
    wsR.Cells(rh, 4).Value = "分類"
    wsR.Cells(rh, 5).Value = "純売上金額"
    wsR.Cells(rh, 6).Value = "数量"

    For i = 1 To 5
        r = rh + i
        If i <= nu Then
            wsR.Cells(r, 1).Value = i
            wsR.Cells(r, 2).Value = pCode(i)
            wsR.Cells(r, 3).Value = pName(i)
            wsR.Cells(r, 4).Value = pBun(i)
            wsR.Cells(r, 5).Value = pKin(i)
            wsR.Cells(r, 6).Value = pSuu(i)
        End If
    Next i

    wsR.Cells(rh + 7, 1).Value = "大口件数"
    wsR.Cells(rh + 7, 2).Value = ooguchi

    ' --- 書式 ---------------------------------------------
    ApplyHeaderFormat2 wsR, hdr, 1, 9
    ApplyHeaderFormat2 wsR, rh, 1, 6
    MarkTotalRow wsR, sum, 1, 9
    FormatMoneyColumn wsR, 4, first, sum
    FormatMoneyColumn wsR, 5, first, sum
    FormatMoneyColumn wsR, 6, first, sum
    FormatMoneyColumn wsR, 7, first, sum
    FormatMoneyColumn wsR, 5, rh + 1, rh + 5
    SetTitleStyle wsR, "A1"
    FitColumns wsR, 1, 9
End Sub
