Attribute VB_Name = "RunnerClipboard"
Option Explicit

Public Sub E1_CopyFixture01ToClipboard()
    ExecuteClipboardOutputCase "E1", "01", True
End Sub

Public Sub E2_CopyFixture02ToClipboard()
    ExecuteClipboardOutputCase "E2", "02", True
End Sub

Public Sub F1_ImportClipboardForFixture01()
    ExecuteClipboardInputCase "F1", "01", True
End Sub

Public Sub F2_ImportClipboardForFixture02()
    ExecuteClipboardInputCase "F2", "02", True
End Sub

Public Function ExecuteClipboardOutputCase( _
    ByVal caseId As String, _
    ByVal fixtureId As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim bufferSheet As Worksheet
    Dim detailText As String
    Dim sourcePath As String
    Dim sourceText As String
    Dim startedAt As Date
    Dim target As Range

    On Error GoTo Failed
    sourcePath = FixtureMirrorPath(fixtureId)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read the selected external source mirror only now, place " & _
                "it in one visible Excel cell, and copy that cell to " & _
                "the clipboard.", _
            sourcePath, _
            CLIPBOARD_SHEET_NAME & "!B2 in memory and clipboard", _
            "The selected text is copied. No network or other " & _
                "application is contacted.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    sourceText = SourceBodyFromExport(ReadTextFile(sourcePath))
    If Len(sourceText) = 0 Then
        Err.Raise vbObjectError + 2630, _
            "MacroStudioValidation", _
            "The selected source mirror was empty."
    End If

    Set bufferSheet = ThisWorkbook.Worksheets(CLIPBOARD_SHEET_NAME)
    Set target = bufferSheet.Range("B2")
    target.value2 = sourceText
    detailText = _
        "fixture=" & fixtureId & _
        "; characters=" & CStr(Len(sourceText)) & _
        "; copied=true"

    RecordCaseResult _
        startedAt, caseId, "PASS", sourcePath, _
        CLIPBOARD_SHEET_NAME & "!B2 in memory and clipboard", _
        detailText

    bufferSheet.Activate
    target.Select
    target.Copy

    If interactive Then
        ShowCaseResult _
            caseId, True, sourcePath, _
            CLIPBOARD_SHEET_NAME & "!B2 in memory and clipboard", _
            detailText
    End If
    ExecuteClipboardOutputCase = True
    Exit Function

Failed:
    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ErrorText(Err.Number, Err.Description)
    RecordCaseResult _
        startedAt, caseId, "FAIL", sourcePath, _
        CLIPBOARD_SHEET_NAME & "!B2 in memory and clipboard", _
        detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, sourcePath, _
            CLIPBOARD_SHEET_NAME & "!B2 in memory and clipboard", _
            detailText
    End If
End Function

Public Function ExecuteClipboardInputCase( _
    ByVal caseId As String, _
    ByVal fixtureId As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim detailText As String
    Dim expectedPath As String
    Dim expectedText As String
    Dim outputBook As Workbook
    Dim outputPath As String
    Dim pastedText As String
    Dim startedAt As Date
    Dim target As Range

    On Error GoTo Failed
    expectedPath = FixtureMirrorPath(fixtureId)
    outputPath = UniqueOutputPath( _
        caseId & "_fixture-" & fixtureId & "_clipboard-copy", _
        ".xlsx")

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Paste the current Excel-cell clipboard value into a new " & _
                "workbook under output, save it, then compare the value " & _
                "with the selected external source mirror.", _
            "clipboard; expected mirror: " & expectedPath, _
            outputPath & " :: Output!A1", _
            "Run the matching E case immediately before this case. " & _
                "The pasted value matches and only the new output file " & _
                "is saved.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    EnsureOutputFolder
    expectedText = SourceBodyFromExport(ReadTextFile(expectedPath))
    If Len(expectedText) = 0 Then
        Err.Raise vbObjectError + 2631, _
            "MacroStudioValidation", _
            "The selected source mirror was empty."
    End If

    Set outputBook = Application.Workbooks.Add(xlWBATWorksheet)
    outputBook.Worksheets(1).Name = "Output"
    Set target = outputBook.Worksheets(1).Range("A1")
    outputBook.Worksheets(1).Activate
    target.Select
    target.PasteSpecial Paste:=xlPasteValues
    pastedText = CStr(target.value2)

    outputBook.SaveAs _
        Filename:=outputPath, _
        FileFormat:=xlOpenXMLWorkbook, _
        CreateBackup:=False
    outputBook.Close SaveChanges:=False
    Set outputBook = Nothing
    Application.CutCopyMode = False

    If NormalizeSourceText(expectedText) <> _
        NormalizeSourceText(pastedText) Then
        Err.Raise vbObjectError + 2632, _
            "MacroStudioValidation", _
            "Clipboard content did not match the selected fixture."
    End If

    detailText = _
        "fixture=" & fixtureId & _
        "; characters=" & CStr(Len(pastedText)) & _
        "; exact_match=true"
    RecordCaseResult _
        startedAt, caseId, "PASS", _
        "clipboard; expected mirror: " & expectedPath, _
        outputPath & " :: Output!A1", detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, _
            "clipboard; expected mirror: " & expectedPath, _
            outputPath & " :: Output!A1", detailText
    End If
    ExecuteClipboardInputCase = True
    Exit Function

Failed:
    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ErrorText(Err.Number, Err.Description)
    On Error Resume Next
    If Not outputBook Is Nothing Then
        outputBook.Close SaveChanges:=False
    End If
    Application.CutCopyMode = False
    On Error GoTo 0

    RecordCaseResult _
        startedAt, caseId, "FAIL", _
        "clipboard; expected mirror: " & expectedPath, _
        outputPath & " :: Output!A1", detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, _
            "clipboard; expected mirror: " & expectedPath, _
            outputPath & " :: Output!A1", detailText
    End If
End Function
