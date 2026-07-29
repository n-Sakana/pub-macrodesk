Option Explicit

'============================================================
' 月次売上集計マクロ  共通処理
'
' 2019/04  初版（総務課）
' 2020/10  支店マスタを追加
' 2021/09  返品区分の扱いを追加
' 2023/06  目標達成率の判定を追加
' 2024/11  点検リストの出力を追加
' 2025/07  対象年月を設定シートから読むように変更
'
' ※ 直したい人へ: シート名は各所に直書きしています。
'    下の Const は途中まで置き換えたところで止まっています。
'============================================================

Public Const SHEET_MEISAI As String = "売上明細"
Public Const SHEET_SETTEI As String = "設定"

' 集計中に持ち回る値。あちこちから参照しています。
Public g_TargetYm As String
Public g_LargeAmount As Double
Public g_CheckRow As Long
Public g_Message As String
Public g_Ready As Boolean
Public g_SkipCount As Long
Public g_NoMasterCount As Long
Public g_TotalUri As Double
Public g_TotalHen As Double

Public Sub InitGlobals()
    g_TargetYm = ""
    g_LargeAmount = 0
    g_CheckRow = 1
    g_Message = ""
    g_Ready = False
    g_SkipCount = 0
    g_NoMasterCount = 0
    g_TotalUri = 0
    g_TotalHen = 0
End Sub

Public Function GetSheet(ByVal nm As String) As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(nm)
    On Error GoTo 0
    Set GetSheet = ws
End Function

' 最終行の取り方が 3 通りあります。書いた人が違います。
Public Function LastRow1(ws As Worksheet) As Long
    LastRow1 = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
End Function

Public Function LastRow2(ws As Worksheet, ByVal col As Long) As Long
    Dim r As Long
    r = ws.Cells(ws.Rows.Count, col).End(xlUp).Row
    If r < 1 Then
        r = 1
    End If
    LastRow2 = r
End Function

Public Function GetLastRow(ws As Worksheet) As Long
    Dim ur As Range
    Set ur = ws.UsedRange
    GetLastRow = ur.Row + ur.Rows.Count - 1
End Function

' 設定シートの読み出し。キーは A 列、値は B 列。
Public Function GetSetteiValue(ByVal k As String) As Variant
    Dim ws As Worksheet
    Dim i As Long
    Dim n As Long
    Dim v As Variant

    Set ws = ThisWorkbook.Worksheets("設定")
    n = LastRow1(ws)
    v = ""
    For i = 2 To n
        If Trim(CStr(ws.Cells(i, 1).Value)) = k Then
            v = ws.Cells(i, 2).Value
            Exit For
        End If
    Next i
    GetSetteiValue = v
End Function

' 年月を "yyyymm" の文字列にします。
Public Function ToYm(ByVal d As Variant) As String
    Dim dt As Date

    If IsDate(d) Then
        dt = CDate(d)
        ToYm = Format(dt, "yyyymm")
    Else
        ToYm = ""
    End If
End Function

' 商品マスタから 1 件引きます。線形探索です。件数が増えたら遅いです。
Public Function FindProductRow(ByVal cd As String) As Long
    Dim ws As Worksheet
    Dim i As Long
    Dim n As Long

    Set ws = ThisWorkbook.Worksheets("商品マスタ")
    n = LastRow1(ws)
    FindProductRow = 0
    For i = 2 To n
        If Trim(CStr(ws.Cells(i, 1).Value)) = cd Then
            FindProductRow = i
            Exit For
        End If
    Next i
End Function

' 支店マスタ側は Match を使っています。上とやっていることは同じです。
Public Function FindBranchRow(ByVal cd As String) As Long
    Dim ws As Worksheet
    Dim n As Long
    Dim r As Variant

    Set ws = ThisWorkbook.Worksheets("支店マスタ")
    n = LastRow1(ws)
    On Error Resume Next
    r = Application.Match(cd, ws.Range(ws.Cells(2, 1), ws.Cells(n, 1)), 0)
    On Error GoTo 0
    If IsNumeric(r) Then
        FindBranchRow = CLng(r) + 1
    Else
        FindBranchRow = 0
    End If
End Function

' 点検リストへ 1 行足します。行位置はグローバルで持ち回っています。
Public Sub AddCheck(ByVal kind As String, ByVal denpyo As String, _
                    ByVal branch As String, ByVal product As String, _
                    ByVal naiyo As String, ByVal kingaku As Double)
    Dim ws As Worksheet

    Set ws = ThisWorkbook.Worksheets("点検リスト")
    g_CheckRow = g_CheckRow + 1
    ws.Cells(g_CheckRow, 1).Value = kind
    ws.Cells(g_CheckRow, 2).Value = denpyo
    ws.Cells(g_CheckRow, 3).Value = branch
    ws.Cells(g_CheckRow, 4).Value = product
    ws.Cells(g_CheckRow, 5).Value = naiyo
    ws.Cells(g_CheckRow, 6).Value = kingaku
End Sub

' 数値にできないものが混ざっても落ちないように、という意図で置いた関数。
Public Function Num(ByVal v As Variant) As Double
    Dim d As Double

    d = 0
    On Error Resume Next
    If IsNumeric(v) Then
        d = CDbl(v)
    End If
    On Error GoTo 0
    Num = d
End Function

Public Function Txt(ByVal v As Variant) As String
    Txt = Trim(CStr(v))
End Function
