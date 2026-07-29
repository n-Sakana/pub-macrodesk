Option Explicit

'============================================================
' 担当者別の集計と、伝票番号の重複チェック
'
' 2023/10  「担当者ごとの数字も出して」と言われて足しました。
' 2024/02  伝票番号の重複が見つかったので、チェックも
'          ここへ入れました。
'
' 明細はまた頭から読み直しています。担当者は何人になるか
' 分からないので、出てくるたびに配列を広げています。
'============================================================

Public Sub BuildStaffSummary()
    Dim ws As Worksheet
    Dim wsS As Worksheet
    Dim nm() As String
    Dim ken() As Long
    Dim uri() As Double
    Dim hen() As Double
    Dim cnt As Long
    Dim i As Long, j As Long, n As Long, r As Long
    Dim s As String, kb As String, sl As String
    Dim q As Double, t As Double, kin As Double
    Dim idx As Long
    Dim run As Double
    Dim ts As Double, th As Double
    Dim tk As Long

    Set ws = ThisWorkbook.Worksheets("売上明細")
    Set wsS = ThisWorkbook.Worksheets("担当者別")
    ClearOutputArea wsS

    n = LastRow1(ws)
    cnt = 0

    ' --- 担当者ごとに足す ---------------------------------
    For i = 2 To n
        If IsTargetMonth(ws.Cells(i, 2).Value) = True Then
            s = Txt(ws.Cells(i, 8).Value)
            kb = Txt(ws.Cells(i, 7).Value)
            q = Num(ws.Cells(i, 5).Value)
            t = Num(ws.Cells(i, 6).Value)
            kin = q * t

            ' 既に出てきた担当者かどうかを毎回頭から探しています。
            idx = 0
            For j = 1 To cnt
                If nm(j) = s Then
                    idx = j
                    Exit For
                End If
            Next j

            If idx = 0 Then
                cnt = cnt + 1
                ReDim Preserve nm(1 To cnt)
                ReDim Preserve ken(1 To cnt)
                ReDim Preserve uri(1 To cnt)
                ReDim Preserve hen(1 To cnt)
                nm(cnt) = s
                ken(cnt) = 0
                uri(cnt) = 0
                hen(cnt) = 0
                idx = cnt
            End If

            ken(idx) = ken(idx) + 1
            If IsHenpin(kb) = True Then
                hen(idx) = hen(idx) + kin
            Else
                uri(idx) = uri(idx) + kin
            End If
        End If
    Next i

    ' --- 書き出し -----------------------------------------
    ' 並びは明細に出てきた順です。上から累計を足していきます。
    wsS.Cells(1, 1).Value = "担当者別集計"
    wsS.Range("B2").NumberFormatLocal = "@"
    wsS.Cells(2, 1).Value = "対象年月"
    wsS.Cells(2, 2).Value = Left(g_TargetYm, 4) & "年" & Right(g_TargetYm, 2) & "月"

    wsS.Cells(4, 1).Value = "連番"
    wsS.Cells(4, 2).Value = "担当者"
    wsS.Cells(4, 3).Value = "件数"
    wsS.Cells(4, 4).Value = "売上金額"
    wsS.Cells(4, 5).Value = "返品金額"
    wsS.Cells(4, 6).Value = "純売上"
    wsS.Cells(4, 7).Value = "累計純売上"

    run = 0
    ts = 0
    th = 0
    tk = 0
    For i = 1 To cnt
        r = 4 + i
        run = run + (uri(i) - hen(i))
        wsS.Cells(r, 1).Value = i
        wsS.Cells(r, 2).Value = nm(i)
        wsS.Cells(r, 3).Value = ken(i)
        wsS.Cells(r, 4).Value = uri(i)
        wsS.Cells(r, 5).Value = hen(i)
        wsS.Cells(r, 6).Value = uri(i) - hen(i)
        wsS.Cells(r, 7).Value = run
        ts = ts + uri(i)
        th = th + hen(i)
        tk = tk + ken(i)
    Next i

    r = 5 + cnt
    wsS.Cells(r, 2).Value = "合計"
    wsS.Cells(r, 3).Value = tk
    wsS.Cells(r, 4).Value = ts
    wsS.Cells(r, 5).Value = th
    wsS.Cells(r, 6).Value = ts - th

    ApplyHeaderFormat wsS, 4, 1, 7
    MarkTotalRow wsS, r, 1, 7
    FormatMoneyColumn wsS, 4, 5, r
    FormatMoneyColumn wsS, 5, 5, r
    FormatMoneyColumn wsS, 6, 5, r
    FormatMoneyColumn wsS, 7, 5, r
    SetTitleStyle wsS, "A1"
    FitColumns wsS, 1, 7

    CheckDuplicateSlips
End Sub

' 伝票番号が二重に入っていないかを見ます。
' 総当たりなので明細が増えると重くなります。
Public Sub CheckDuplicateSlips()
    Dim ws As Worksheet
    Dim i As Long, j As Long, n As Long
    Dim sl As String

    Set ws = ThisWorkbook.Worksheets("売上明細")
    n = LastRow1(ws)

    For i = 2 To n
        If IsTargetMonth(ws.Cells(i, 2).Value) = True Then
            sl = Txt(ws.Cells(i, 1).Value)
            For j = 2 To i - 1
                If IsTargetMonth(ws.Cells(j, 2).Value) = True Then
                    If Txt(ws.Cells(j, 1).Value) = sl Then
                        AddCheck "伝票重複", sl, _
                                 Txt(ws.Cells(i, 3).Value), _
                                 Txt(ws.Cells(i, 4).Value), _
                                 "同じ伝票番号が複数行にあります", _
                                 Num(ws.Cells(i, 5).Value) * _
                                 Num(ws.Cells(i, 6).Value)
                        Exit For
                    End If
                End If
            Next j
        End If
    Next i
End Sub
