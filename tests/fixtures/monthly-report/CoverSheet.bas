'============================================================
' 報告書（表紙）の作成
'
' 2020/05  提出用の表紙をひな形から貼るようにしました。
'          もともとマクロの記録で作ったものを手直ししています。
'
' 「ひな形」シートは普段は隠してあります。書式と数式ごと
' 持ってきたいので、ここは貼り付けで作っています。
'============================================================

Public gCoverRows As Long

Public Sub BuildCoverSheet()
    Dim wsT As Worksheet
    Dim wsC As Worksheet
    Dim wsR As Worksheet
    Dim s As String

    Set wsT = ThisWorkbook.Worksheets("ひな形")
    Set wsC = ThisWorkbook.Worksheets("報告書")
    Set wsR = ThisWorkbook.Worksheets("支店別レポート")

    ClearOutputArea wsC
    wsC.Activate

    ' 見出しはひな形から。罫線・色・数式ごと持ってきます。
    wsT.Range("A1:C6").Copy
    Range("A1").PasteSpecial xlPasteAll
    Application.CutCopyMode = False

    ' こちらは数字を並べるだけですが、上と同じ書き方にしています。
    wsR.Range("D10:G10").Copy
    Range("B9").PasteSpecial xlPasteValues
    Application.CutCopyMode = False
    Cells(9, 1).Value = "支店合計"

    ' 目標の合計は、レポートに出ている見た目のままの文字で載せます。
    ' 文字列にしておかないと、桁区切りごと数値に戻ってしまいます。
    wsR.Columns(7).ColumnWidth = 18
    s = wsR.Cells(10, 7).Text
    Cells(11, 1).Value = "月次目標合計"
    Cells(11, 2).NumberFormatLocal = "@"
    Cells(11, 2).Value = s

    ActiveWorkbook.Worksheets("報告書").Cells(13, 1).Value = "処理結果"
    Cells(13, 2).Value = g_Message

    gCoverRows = 13
    ActiveSheet.Range("A1").Select
End Sub
