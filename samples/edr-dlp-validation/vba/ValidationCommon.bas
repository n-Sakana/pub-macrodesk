Attribute VB_Name = "ValidationCommon"
Option Explicit
Option Private Module

Public Const CONTROL_SHEET_NAME As String = "Control"
Public Const CLIPBOARD_SHEET_NAME As String = "ClipboardFixture"
Public Const RUN_LOG_SHEET_NAME As String = "RunLog"

Private Const OUTPUT_FOLDER_NAME As String = "output"

Public Function SampleRootPath() As String
    If Len(ThisWorkbook.Path) = 0 Then
        Err.Raise vbObjectError + 2401, _
            "MacroStudioValidation", _
            "Save the validation workbook before running a case."
    End If

    SampleRootPath = ThisWorkbook.Path
End Function

Public Function SampleFilePath(ByVal relativePath As String) As String
    SampleFilePath = SampleRootPath() & _
        Application.PathSeparator & _
        Replace(relativePath, "/", Application.PathSeparator)
End Function

Public Function OutputFolderPath() As String
    OutputFolderPath = SampleFilePath(OUTPUT_FOLDER_NAME)
End Function

Public Sub EnsureOutputFolder()
    Dim folderPath As String

    folderPath = OutputFolderPath()
    If Len(Dir$(folderPath, vbDirectory)) = 0 Then
        MkDir folderPath
    End If
End Sub

Public Function UniqueOutputPath( _
    ByVal prefix As String, _
    ByVal extension As String) As String

    Dim candidate As String
    Dim suffix As String
    Dim attempt As Long
    Dim stamp As String

    stamp = Format$(Now, "yyyymmdd_hhnnss")
    For attempt = 0 To 99
        If attempt = 0 Then
            suffix = vbNullString
        Else
            suffix = "_" & Format$(attempt, "00")
        End If

        candidate = OutputFolderPath() & _
            Application.PathSeparator & _
            prefix & "_" & stamp & suffix & extension
        If Len(Dir$(candidate)) = 0 Then
            UniqueOutputPath = candidate
            Exit Function
        End If
    Next attempt

    Err.Raise vbObjectError + 2402, _
        "MacroStudioValidation", _
        "Could not choose a new output name."
End Function

Public Function ConfirmCase( _
    ByVal caseId As String, _
    ByVal actionText As String, _
    ByVal inputText As String, _
    ByVal outputText As String, _
    ByVal expectedText As String) As Boolean

    Dim message As String

    message = "Case: " & caseId & vbCrLf & vbCrLf & _
        "Action" & vbCrLf & actionText & vbCrLf & vbCrLf & _
        "Input" & vbCrLf & inputText & vbCrLf & vbCrLf & _
        "Output" & vbCrLf & outputText & vbCrLf & vbCrLf & _
        "Expected" & vbCrLf & expectedText & vbCrLf & vbCrLf & _
        "No case action has run yet. Choose OK to run this one case."

    ConfirmCase = (MsgBox( _
        message, _
        vbOKCancel Or vbInformation, _
        "MacroStudio EDR/DLP validation") = vbOK)
End Function

Public Sub RecordCaseResult( _
    ByVal startedAt As Date, _
    ByVal caseId As String, _
    ByVal statusText As String, _
    ByVal inputText As String, _
    ByVal outputText As String, _
    ByVal detailText As String)

    Dim logSheet As worksheet
    Dim nextRow As Long

    Set logSheet = ThisWorkbook.Worksheets(RUN_LOG_SHEET_NAME)
    nextRow = logSheet.Cells(logSheet.Rows.Count, 1).End(xlUp).Row + 1
    If nextRow < 2 Then
        nextRow = 2
    End If

    logSheet.Cells(nextRow, 1).Value = _
        Format$(startedAt, "yyyy-mm-dd hh:nn:ss")
    logSheet.Cells(nextRow, 2).Value = _
        Format$(Now, "yyyy-mm-dd hh:nn:ss")
    logSheet.Cells(nextRow, 3).Value = caseId
    logSheet.Cells(nextRow, 4).Value = statusText
    logSheet.Cells(nextRow, 5).Value = OneLine(inputText)
    logSheet.Cells(nextRow, 6).Value = OneLine(outputText)
    logSheet.Cells(nextRow, 7).Value = OneLine(detailText)
    logSheet.Columns("A:G").AutoFit
End Sub

Public Sub ShowCaseResult( _
    ByVal caseId As String, _
    ByVal succeeded As Boolean, _
    ByVal inputText As String, _
    ByVal outputText As String, _
    ByVal detailText As String)

    Dim iconStyle As VbMsgBoxStyle
    Dim statusText As String

    If succeeded Then
        statusText = "PASS"
        iconStyle = vbInformation
    Else
        statusText = "FAIL"
        iconStyle = vbExclamation
    End If

    MsgBox _
        "Case: " & caseId & vbCrLf & _
        "Result: " & statusText & vbCrLf & vbCrLf & _
        "Input" & vbCrLf & inputText & vbCrLf & vbCrLf & _
        "Output" & vbCrLf & outputText & vbCrLf & vbCrLf & _
        "Detail" & vbCrLf & PreviewText(detailText, 800), _
        iconStyle, _
        "MacroStudio EDR/DLP validation"
End Sub

Public Function ReadComponentSource(ByVal component As Object) As String
    Dim lineCount As Long

    lineCount = component.CodeModule.CountOfLines
    If lineCount = 0 Then
        ReadComponentSource = vbNullString
    Else
        ReadComponentSource = component.CodeModule.Lines(1, lineCount)
    End If
End Function

Public Function NormalizeSourceText(ByVal sourceText As String) As String
    Dim normalized As String

    normalized = Replace(sourceText, vbCrLf, vbLf)
    normalized = Replace(normalized, vbCr, vbLf)
    Do While Len(normalized) > 0 And Right$(normalized, 1) = vbLf
        normalized = Left$(normalized, Len(normalized) - 1)
    Loop

    NormalizeSourceText = normalized
End Function

Public Function PreviewText( _
    ByVal text As String, _
    ByVal maximumLength As Long) As String

    If Len(text) <= maximumLength Then
        PreviewText = text
    Else
        PreviewText = Left$(text, maximumLength) & _
            vbCrLf & "[preview truncated]"
    End If
End Function

Public Function OneLine(ByVal text As String) As String
    Dim result As String

    result = Replace(text, vbCrLf, " | ")
    result = Replace(result, vbCr, " | ")
    result = Replace(result, vbLf, " | ")
    result = Replace(result, vbTab, " ")
    OneLine = result
End Function
