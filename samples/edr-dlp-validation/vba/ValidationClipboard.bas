Attribute VB_Name = "ValidationClipboard"
Option Explicit

Private Const FIXED_REQUEST_TEXT As String = _
    "Review this harmless validation sample and summarize its visible " & _
    "inputs, outputs, and safety boundaries."

Public Sub C1_CopyFixedText_ToClipboard()
    ExecuteClipboardWriteCase True
End Sub

Public Sub D1_ReadClipboardText_Explicit()
    ExecuteClipboardReadCase True
End Sub

Public Function ExecuteClipboardWriteCase( _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim detailText As String
    Dim startedAt As Date
    Dim target As Range
    Dim fixtureSheet As worksheet

    On Error GoTo Failed
    startedAt = Now
    Set fixtureSheet = ThisWorkbook.Worksheets(CLIPBOARD_SHEET_NAME)
    Set target = fixtureSheet.Range("B2")

    If interactive Then
        If Not ConfirmCase( _
            "C1", _
            "Place the fixed harmless request-like text shown below " & _
                "onto the clipboard by copying one visible Excel cell.", _
            FIXED_REQUEST_TEXT, _
            CLIPBOARD_SHEET_NAME & "!B2 and the Windows clipboard", _
            "The exact fixed text is copied. No network or other " & _
                "application is contacted.") Then
            Exit Function
        End If
    End If

    target.Value2 = FIXED_REQUEST_TEXT
    detailText = "Characters copied: " & CStr(Len(FIXED_REQUEST_TEXT)) & _
        vbCrLf & "Content:" & vbCrLf & FIXED_REQUEST_TEXT
    RecordCaseResult _
        startedAt, "C1", "PASS", _
        FIXED_REQUEST_TEXT, _
        CLIPBOARD_SHEET_NAME & "!B2 and clipboard", _
        "characters=" & CStr(Len(FIXED_REQUEST_TEXT))

    ' Copy last. Editing RunLog after this point would make Excel leave
    ' copy mode and would no longer represent a successful clipboard case.
    fixtureSheet.Activate
    target.Select
    target.Copy

    If interactive Then
        ShowCaseResult _
            "C1", True, _
            FIXED_REQUEST_TEXT, _
            CLIPBOARD_SHEET_NAME & "!B2 and clipboard", _
            detailText
    End If
    ExecuteClipboardWriteCase = True
    Exit Function

Failed:
    detailText = "Error " & CStr(Err.Number) & ": " & Err.Description
    RecordCaseResult _
        startedAt, "C1", "FAIL", _
        FIXED_REQUEST_TEXT, _
        CLIPBOARD_SHEET_NAME & "!B2 and clipboard", _
        detailText
    If interactive Then
        ShowCaseResult _
            "C1", False, _
            FIXED_REQUEST_TEXT, _
            CLIPBOARD_SHEET_NAME & "!B2 and clipboard", _
            detailText
    End If
End Function

Public Function ExecuteClipboardReadCase( _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim detailText As String
    Dim failureDescription As String
    Dim failureNumber As Long
    Dim pastedText As String
    Dim startedAt As Date
    Dim target As Range
    Dim fixtureSheet As worksheet

    On Error GoTo Failed
    startedAt = Now
    Set fixtureSheet = ThisWorkbook.Worksheets(CLIPBOARD_SHEET_NAME)
    Set target = fixtureSheet.Range("A6")

    If interactive Then
        If Not ConfirmCase( _
            "D1", _
            "Paste clipboard data explicitly as an Excel cell value " & _
                "into the " & _
                "visible fixture sheet, then report the content, " & _
                "character count, and success or failure.", _
            "Current clipboard text copied by C1 or another Excel cell", _
            CLIPBOARD_SHEET_NAME & "!A6", _
            "Text is shown in the sheet and in the result dialog. " & _
                "Unsupported clipboard data is reported as a failure.") Then
            Exit Function
        End If
    End If

    fixtureSheet.Activate
    target.Select
    target.PasteSpecial Paste:=xlPasteValues
    pastedText = CStr(target.Value2)

    If Len(pastedText) = 0 Then
        Err.Raise vbObjectError + 2430, _
            "MacroStudioValidation", _
            "The clipboard did not provide non-empty Unicode text."
    End If

    fixtureSheet.Range("B3").Value2 = _
        "PASS - characters: " & CStr(Len(pastedText))
    Application.CutCopyMode = False
    detailText = "Characters read: " & CStr(Len(pastedText)) & _
        vbCrLf & "Content:" & vbCrLf & pastedText
    RecordCaseResult _
        startedAt, "D1", "PASS", _
        "clipboard", _
        CLIPBOARD_SHEET_NAME & "!A6", _
        "characters=" & CStr(Len(pastedText))
    If interactive Then
        ShowCaseResult _
            "D1", True, _
            "clipboard", _
            CLIPBOARD_SHEET_NAME & "!A6", _
            detailText
    End If
    ExecuteClipboardReadCase = True
    Exit Function

Failed:
    failureNumber = Err.Number
    failureDescription = Err.Description
    detailText = "Error " & CStr(failureNumber) & _
        ": " & failureDescription
    On Error Resume Next
    fixtureSheet.Range("B3").Value2 = "FAIL - " & failureDescription
    On Error GoTo 0
    RecordCaseResult _
        startedAt, "D1", "FAIL", _
        "clipboard", _
        CLIPBOARD_SHEET_NAME & "!A6", _
        detailText
    If interactive Then
        ShowCaseResult _
            "D1", False, _
            "clipboard", _
            CLIPBOARD_SHEET_NAME & "!A6", _
            detailText
    End If
End Function
