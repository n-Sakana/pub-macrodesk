Option Explicit
100 Rem "C:\\comment-only"
Public Sub Probe()
    Dim value As String
    value = "C:\\Data\\" & _
        "monthly-report.xlsx"
    Debug.Print [Don't "split"]
#If VBA7 Then
    value = "https://example.test/report"
#End If
End Sub
