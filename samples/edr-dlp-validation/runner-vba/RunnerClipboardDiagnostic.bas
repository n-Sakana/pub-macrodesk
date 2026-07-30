Attribute VB_Name = "RunnerClipboardDiagnostic"
Option Explicit

Private Const CLIPBOARD_TO_RUNNER As Long = 0
Private Const CLIPBOARD_TO_NEW_BOOK As Long = 1
Private Const CLIPBOARD_TO_SAVED_BOOK As Long = 2

Public Sub Y01_Fixture01_PasteToRunnerOnly()
    ExecuteClipboardDiagnosticCase _
        "Y01", "01", CLIPBOARD_TO_RUNNER, True
End Sub

Public Sub Y02_Fixture01_PasteToNewBookNoSave()
    ExecuteClipboardDiagnosticCase _
        "Y02", "01", CLIPBOARD_TO_NEW_BOOK, True
End Sub

Public Sub Y03_Fixture01_PasteToNewBookAndSave()
    ExecuteClipboardDiagnosticCase _
        "Y03", "01", CLIPBOARD_TO_SAVED_BOOK, True
End Sub

Public Sub Y04_Fixture02_PasteToRunnerOnly()
    ExecuteClipboardDiagnosticCase _
        "Y04", "02", CLIPBOARD_TO_RUNNER, True
End Sub

Public Sub Y05_Fixture02_PasteToNewBookNoSave()
    ExecuteClipboardDiagnosticCase _
        "Y05", "02", CLIPBOARD_TO_NEW_BOOK, True
End Sub

Public Sub Y06_Fixture02_PasteToNewBookAndSave()
    ExecuteClipboardDiagnosticCase _
        "Y06", "02", CLIPBOARD_TO_SAVED_BOOK, True
End Sub

Public Function ExecuteClipboardDiagnosticCase( _
    ByVal caseId As String, _
    ByVal fixtureId As String, _
    ByVal operationMode As Long, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim bufferSheet As Worksheet
    Dim detailText As String
    Dim errorDescription As String
    Dim errorNumber As Long
    Dim newBook As Workbook
    Dim outputPath As String
    Dim pastedText As String
    Dim startedAt As Date
    Dim target As Range

    On Error GoTo Failed
    ValidateClipboardOperation operationMode
    If operationMode = CLIPBOARD_TO_SAVED_BOOK Then
        EnsureOutputFolder
        outputPath = UniqueOutputPath( _
            caseId & "_fixture-" & fixtureId & "_clipboard", _
            ".xlsx")
    ElseIf operationMode = CLIPBOARD_TO_NEW_BOOK Then
        outputPath = "(new workbook closed without saving)"
    Else
        outputPath = CLIPBOARD_SHEET_NAME & "!D2 in memory"
    End If

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            ClipboardActionText(operationMode), _
            "current Excel-cell clipboard; no external file read", _
            outputPath & " and " & DiagnosticLogPath(), _
            "Run the matching E case immediately before this one. " & _
                "This case isolates paste, new-workbook creation, and " & _
                "save boundaries without rereading a source mirror.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, "TEST_START", "OK", _
        "operation=" & ClipboardOperationName(operationMode) & _
        "; external_fixture_read=false"

    If operationMode = CLIPBOARD_TO_RUNNER Then
        Set bufferSheet = _
            ThisWorkbook.Worksheets(CLIPBOARD_SHEET_NAME)
        Set target = bufferSheet.Range("D2")
        bufferSheet.Activate
        target.Select
        AppendDiagnosticStage _
            caseId, "fixture-" & fixtureId, _
            "RUNNER_TARGET_READY", "OK", _
            "target=" & CLIPBOARD_SHEET_NAME & "!D2"
    Else
        AppendDiagnosticStage _
            caseId, "fixture-" & fixtureId, _
            "BOOK_CREATE_ATTEMPT", "START", _
            "save=" & BooleanTextForClipboard( _
                operationMode = CLIPBOARD_TO_SAVED_BOOK)
        Set newBook = Application.Workbooks.Add(xlWBATWorksheet)
        newBook.Worksheets(1).Name = "Output"
        Set target = newBook.Worksheets(1).Range("A1")
        newBook.Worksheets(1).Activate
        target.Select
        AppendDiagnosticStage _
            caseId, "fixture-" & fixtureId, _
            "BOOK_CREATED", "OK", _
            "target=Output!A1"
    End If

    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, _
        "PASTE_ATTEMPT", "START", _
        "paste=values"
    target.PasteSpecial Paste:=xlPasteValues
    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, "PASTE_OK", "OK", _
        "paste=values"

    pastedText = CStr(target.value2)
    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, "VALUE_READ_OK", "OK", _
        "characters=" & CStr(Len(pastedText))
    If Len(pastedText) <> _
        ExpectedClipboardCharacters(fixtureId) Then
        Err.Raise vbObjectError + 2690, _
            "MacroStudioValidation", _
            "The pasted value had an unexpected character count. " & _
                "Run the matching E case immediately before retrying."
    End If
    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, _
        "LENGTH_CHECK_OK", "OK", _
        "characters=" & CStr(Len(pastedText)) & _
        "; expected_match=true"

    If operationMode = CLIPBOARD_TO_SAVED_BOOK Then
        AppendDiagnosticStage _
            caseId, "fixture-" & fixtureId, _
            "SAVE_ATTEMPT", "START", _
            "output=" & outputPath
        newBook.SaveAs _
            Filename:=outputPath, _
            FileFormat:=xlOpenXMLWorkbook, _
            CreateBackup:=False
        AppendDiagnosticStage _
            caseId, "fixture-" & fixtureId, "SAVE_OK", "OK", _
            "output=" & outputPath
    End If

    If Not newBook Is Nothing Then
        newBook.Close SaveChanges:=False
        Set newBook = Nothing
        AppendDiagnosticStage _
            caseId, "fixture-" & fixtureId, _
            "BOOK_CLOSE_OK", "OK", _
            "saved=" & BooleanTextForClipboard( _
                operationMode = CLIPBOARD_TO_SAVED_BOOK)
    End If
    Application.CutCopyMode = False

    detailText = _
        "fixture=" & fixtureId & _
        "; operation=" & ClipboardOperationName(operationMode) & _
        "; characters=" & CStr(Len(pastedText)) & _
        "; external_fixture_read=false"
    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, _
        "CASE_END", "PASS", detailText
    RecordCaseResult _
        startedAt, caseId, "PASS", _
        "current Excel-cell clipboard", outputPath, detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, _
            "current Excel-cell clipboard", outputPath, detailText
    End If
    ExecuteClipboardDiagnosticCase = True
    Exit Function

Failed:
    errorNumber = Err.Number
    errorDescription = Err.Description
    On Error Resume Next
    If Not newBook Is Nothing Then
        newBook.Close SaveChanges:=False
        AppendDiagnosticStage _
            caseId, "fixture-" & fixtureId, _
            "BOOK_CLOSE_AFTER_ERROR", "OK", _
            "saved=false"
    End If
    Application.CutCopyMode = False
    detailText = ErrorText(errorNumber, errorDescription)
    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, _
        "ERROR", "FAIL", detailText
    AppendDiagnosticStage _
        caseId, "fixture-" & fixtureId, _
        "CASE_END", "FAIL", detailText
    RecordCaseResult _
        startedAt, caseId, "FAIL", _
        "current Excel-cell clipboard", outputPath, detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, _
            "current Excel-cell clipboard", outputPath, detailText
    End If
    On Error GoTo 0
End Function

Private Function BooleanTextForClipboard( _
    ByVal value As Boolean) As String

    If value Then
        BooleanTextForClipboard = "true"
    Else
        BooleanTextForClipboard = "false"
    End If
End Function

Private Function ClipboardActionText( _
    ByVal operationMode As Long) As String

    Select Case operationMode
        Case CLIPBOARD_TO_RUNNER
            ClipboardActionText = _
                "Paste the current Excel-cell clipboard value into a " & _
                "visible runner cell in memory only."
        Case CLIPBOARD_TO_NEW_BOOK
            ClipboardActionText = _
                "Create a new workbook, paste the current Excel-cell " & _
                "clipboard value, inspect it, and close without saving."
        Case CLIPBOARD_TO_SAVED_BOOK
            ClipboardActionText = _
                "Create a new workbook, paste the current Excel-cell " & _
                "clipboard value, and save only a new output copy."
    End Select
End Function

Private Function ClipboardOperationName( _
    ByVal operationMode As Long) As String

    Select Case operationMode
        Case CLIPBOARD_TO_RUNNER
            ClipboardOperationName = "paste_to_runner_memory"
        Case CLIPBOARD_TO_NEW_BOOK
            ClipboardOperationName = "paste_to_new_book_no_save"
        Case CLIPBOARD_TO_SAVED_BOOK
            ClipboardOperationName = "paste_to_new_book_and_save"
    End Select
End Function

Private Function ExpectedClipboardCharacters( _
    ByVal fixtureId As String) As Long

    Select Case fixtureId
        Case "01"
            ExpectedClipboardCharacters = 78
        Case "02"
            ExpectedClipboardCharacters = 195
        Case Else
            Err.Raise vbObjectError + 2691, _
                "MacroStudioValidation", _
                "Unknown clipboard diagnostic item id."
    End Select
End Function

Private Sub ValidateClipboardOperation(ByVal operationMode As Long)
    If operationMode < CLIPBOARD_TO_RUNNER Or _
        operationMode > CLIPBOARD_TO_SAVED_BOOK Then
        Err.Raise vbObjectError + 2692, _
            "MacroStudioValidation", _
            "Unknown clipboard diagnostic operation."
    End If
End Sub
