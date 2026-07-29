'============================================================
' 月次売上集計マクロ  書式まわり
'
' 見た目の調整をまとめたモジュール。
' 似たような手続きが増えてしまって、どれを呼べばよいのか
' 分からなくなっています。色は各所に直書きです。
'============================================================

' 見出し行の書式。集計表で使っています。
Public Sub ApplyHeaderFormat(ws As Worksheet, ByVal rowNo As Long, _
                             ByVal colFrom As Long, ByVal colTo As Long)
    Dim rng As Range

    Set rng = ws.Range(ws.Cells(rowNo, colFrom), ws.Cells(rowNo, colTo))
    rng.Font.Bold = True
    rng.Interior.Color = RGB(221, 235, 247)
    rng.HorizontalAlignment = xlCenter
    rng.Borders(xlEdgeBottom).LineStyle = xlContinuous
    rng.Borders(xlEdgeTop).LineStyle = xlContinuous
End Sub

' 支店別レポート用の見出し。上とほとんど同じですが色が違います。
Public Sub ApplyHeaderFormat2(ws As Worksheet, ByVal rowNo As Long, _
                              ByVal colFrom As Long, ByVal colTo As Long)
    Dim rng As Range

    Set rng = ws.Range(ws.Cells(rowNo, colFrom), ws.Cells(rowNo, colTo))
    rng.Font.Bold = True
    rng.Interior.Color = RGB(226, 239, 218)
    rng.HorizontalAlignment = xlCenter
    rng.Borders(xlEdgeBottom).LineStyle = xlContinuous
    rng.Borders(xlEdgeTop).LineStyle = xlContinuous
End Sub

' 点検リストの見出し。3 つ目です。
Public Sub SetCheckHeader(ws As Worksheet)
    ws.Range("A1:F1").Font.Bold = True
    ws.Range("A1:F1").Interior.Color = RGB(252, 228, 214)
    ws.Range("A1:F1").HorizontalAlignment = xlCenter
End Sub

' 表題。ここだけ Select を使って書いています。
Public Sub SetTitleStyle(ws As Worksheet, ByVal addr As String)
    ws.Activate
    ws.Range(addr).Select
    Selection.Font.Bold = True
    Selection.Font.Size = 14
    ActiveSheet.Range("A1").Select
End Sub

' 金額列の表示形式。
Public Sub FormatMoneyColumn(ws As Worksheet, ByVal colNo As Long, _
                             ByVal rowFrom As Long, ByVal rowTo As Long)
    Dim rng As Range

    If rowTo < rowFrom Then
        Exit Sub
    End If
    Set rng = ws.Range(ws.Cells(rowFrom, colNo), ws.Cells(rowTo, colNo))
    rng.NumberFormatLocal = "#,##0"
End Sub

' こちらも金額列の表示形式。範囲の渡し方が違うだけです。
Public Sub SetMoneyFormat(rng As Range)
    rng.NumberFormatLocal = "#,##0"
    rng.HorizontalAlignment = xlRight
End Sub

' 達成率の判定に応じてセルを塗ります。色は直書きです。
Public Sub PaintTassei(ws As Worksheet, ByVal r As Long, ByVal c As Long, _
                       ByVal hantei As String)
    If hantei = "達成" Then
        ws.Cells(r, c).Interior.Color = RGB(198, 239, 206)
    Else
        If hantei = "あと少し" Then
            ws.Cells(r, c).Interior.Color = RGB(255, 235, 156)
        Else
            If hantei = "未達" Then
                ws.Cells(r, c).Interior.Color = RGB(255, 217, 179)
            Else
                ws.Cells(r, c).Interior.Color = RGB(255, 199, 206)
                ws.Cells(r, c).Font.Bold = True
            End If
        End If
    End If
End Sub

' 明細の判定列を塗ります。上と考え方は同じですが別に書いてあります。
Public Sub PaintHantei(ws As Worksheet, ByVal r As Long, ByVal c As Long, _
                       ByVal hantei As String)
    If hantei = "返品" Then
        ws.Cells(r, c).Interior.Color = RGB(255, 217, 179)
    ElseIf hantei = "大口" Then
        ws.Cells(r, c).Interior.Color = RGB(255, 235, 156)
    ElseIf hantei = "要確認" Then
        ws.Cells(r, c).Interior.Color = RGB(255, 199, 206)
    Else
        ws.Cells(r, c).Interior.ColorIndex = xlNone
    End If
End Sub

' 合計行を目立たせます。
Public Sub MarkTotalRow(ws As Worksheet, ByVal rowNo As Long, _
                        ByVal colFrom As Long, ByVal colTo As Long)
    Dim rng As Range

    Set rng = ws.Range(ws.Cells(rowNo, colFrom), ws.Cells(rowNo, colTo))
    rng.Font.Bold = True
    rng.Interior.Color = RGB(242, 242, 242)
    rng.Borders(xlEdgeTop).LineStyle = xlContinuous
End Sub

' 列幅を整えます。シートを表示してから操作しています。
Public Sub FitColumns(ws As Worksheet, ByVal colFrom As Long, ByVal colTo As Long)
    ws.Activate
    ws.Range(ws.Cells(1, colFrom), ws.Cells(1, colTo)).EntireColumn.Select
    Selection.EntireColumn.AutoFit
    ws.Range("A1").Select
End Sub

' 出力シートの中身を消します。範囲は直書きです。
Public Sub ClearOutputArea(ws As Worksheet)
    ws.Range("A1:Z200").ClearContents
    ws.Range("A1:Z200").Interior.ColorIndex = xlNone
    ws.Range("A1:Z200").Font.Bold = False
    ws.Range("A1:Z200").Borders.LineStyle = xlNone
End Sub
