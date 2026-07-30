Attribute VB_Name = "RunnerCommon"
Option Explicit
Option Private Module

Public Const CONTROL_SHEET_NAME As String = "Control"
Public Const CLIPBOARD_SHEET_NAME As String = "ClipboardBuffer"
Public Const RUN_LOG_SHEET_NAME As String = "RunLog"

Private Const FIXTURE_FOLDER_NAME As String = "fixtures"
Private Const MIRROR_FOLDER_NAME As String = "source-mirror"
Private Const OUTPUT_FOLDER_NAME As String = "output"

Public Sub R0_RecordRunnerBaseline()
    ExecuteBaselineCase True
End Sub

Public Function ExecuteBaselineCase( _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim detailText As String
    Dim startedAt As Date

    On Error GoTo Failed

    If interactive Then
        If Not ConfirmCase( _
            "R0", _
            "Record that the runner opened and no external fixture " & _
                "has been selected by a case.", _
            ThisWorkbook.FullName, _
            RUN_LOG_SHEET_NAME & " in memory", _
            "A runner-only baseline row is recorded. No fixture file " & _
                "is read, opened, copied, or changed.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    detailText = "runner_opened=true; fixture_access=false"
    RecordCaseResult _
        startedAt, "R0", "PASS", ThisWorkbook.FullName, _
        RUN_LOG_SHEET_NAME & " in memory", detailText

    If interactive Then
        ShowCaseResult _
            "R0", True, ThisWorkbook.FullName, _
            RUN_LOG_SHEET_NAME & " in memory", detailText
    End If

    ExecuteBaselineCase = True
    Exit Function

Failed:
    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ErrorText(Err.Number, Err.Description)
    RecordCaseResult _
        startedAt, "R0", "FAIL", ThisWorkbook.FullName, _
        RUN_LOG_SHEET_NAME & " in memory", detailText
    If interactive Then
        ShowCaseResult _
            "R0", False, ThisWorkbook.FullName, _
            RUN_LOG_SHEET_NAME & " in memory", detailText
    End If
End Function

Public Function SampleRootPath() As String
    If Len(ThisWorkbook.Path) = 0 Then
        Err.Raise vbObjectError + 2601, _
            "MacroStudioValidation", _
            "Save the runner before using a case."
    End If

    SampleRootPath = ThisWorkbook.Path
End Function

Public Function SampleFilePath(ByVal relativePath As String) As String
    SampleFilePath = SampleRootPath() & _
        Application.PathSeparator & _
        Replace(relativePath, "/", Application.PathSeparator)
End Function

Public Function FixtureBookPath(ByVal fixtureId As String) As String
    ValidateFixtureId fixtureId
    FixtureBookPath = SampleFilePath( _
        FIXTURE_FOLDER_NAME & Application.PathSeparator & _
        "fixture-" & fixtureId & ".xlsm")
End Function

Public Function FixtureMirrorPath(ByVal fixtureId As String) As String
    ValidateFixtureId fixtureId
    FixtureMirrorPath = SampleFilePath( _
        FIXTURE_FOLDER_NAME & Application.PathSeparator & _
        MIRROR_FOLDER_NAME & Application.PathSeparator & _
        "fixture-" & fixtureId & ".bas")
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

    Dim attempt As Long
    Dim candidate As String
    Dim stamp As String
    Dim suffix As String

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

    Err.Raise vbObjectError + 2602, _
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
        "MacroStudio EDR/DLP validation runner") = vbOK)
End Function

Public Sub RecordCaseResult( _
    ByVal startedAt As Date, _
    ByVal caseId As String, _
    ByVal statusText As String, _
    ByVal inputText As String, _
    ByVal outputText As String, _
    ByVal detailText As String)

    Dim logSheet As Worksheet
    Dim nextRow As Long

    Set logSheet = ThisWorkbook.Worksheets(RUN_LOG_SHEET_NAME)
    nextRow = logSheet.Cells(logSheet.Rows.Count, 1).End(xlUp).Row + 1
    If nextRow < 2 Then
        nextRow = 2
    End If

    logSheet.Cells(nextRow, 1).NumberFormat = "@"
    logSheet.Cells(nextRow, 1).value2 = _
        Format$(startedAt, "yyyy-mm-dd hh:nn:ss")
    logSheet.Cells(nextRow, 2).NumberFormat = "@"
    logSheet.Cells(nextRow, 2).value2 = _
        Format$(Now, "yyyy-mm-dd hh:nn:ss")
    logSheet.Cells(nextRow, 3).value = caseId
    logSheet.Cells(nextRow, 4).value = statusText
    logSheet.Cells(nextRow, 5).value = OneLine(inputText)
    logSheet.Cells(nextRow, 6).value = OneLine(outputText)
    logSheet.Cells(nextRow, 7).value = OneLine(detailText)
    logSheet.Columns("A:H").AutoFit
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
        "Excel result: " & statusText & vbCrLf & vbCrLf & _
        "Input" & vbCrLf & inputText & vbCrLf & vbCrLf & _
        "Output" & vbCrLf & outputText & vbCrLf & vbCrLf & _
        "Detail" & vbCrLf & PreviewText(detailText, 800), _
        iconStyle, _
        "MacroStudio EDR/DLP validation runner"
End Sub

Public Sub ReadAllBytes( _
    ByVal filePath As String, _
    ByRef bytes() As Byte, _
    ByRef byteCount As Long)

    Dim errorDescription As String
    Dim errorNumber As Long
    Dim errorSource As String
    Dim fileNumber As Integer

    On Error GoTo Failed
    EnsureFileExists filePath

    fileNumber = FreeFile
    Open filePath For Binary Access Read Lock Read As #fileNumber
    byteCount = LOF(fileNumber)
    If byteCount > 0 Then
        ReDim bytes(0 To byteCount - 1)
        Get #fileNumber, 1, bytes
    Else
        ReDim bytes(0 To 0)
    End If
    Close #fileNumber
    Exit Sub

Failed:
    errorNumber = Err.Number
    errorSource = Err.Source
    errorDescription = Err.Description
    On Error Resume Next
    If fileNumber > 0 Then
        Close #fileNumber
    End If
    On Error GoTo 0
    Err.Raise errorNumber, errorSource, errorDescription
End Sub

Public Sub WriteNewBytes( _
    ByVal filePath As String, _
    ByRef bytes() As Byte, _
    ByVal byteCount As Long)

    Dim errorDescription As String
    Dim errorNumber As Long
    Dim errorSource As String
    Dim fileNumber As Integer

    If Len(Dir$(filePath)) > 0 Then
        Err.Raise vbObjectError + 2603, _
            "MacroStudioValidation", _
            "Refusing to replace an existing output: " & filePath
    End If

    On Error GoTo Failed
    fileNumber = FreeFile
    Open filePath For Binary Access Write Lock Write As #fileNumber
    If byteCount > 0 Then
        Put #fileNumber, 1, bytes
    End If
    Close #fileNumber
    Exit Sub

Failed:
    errorNumber = Err.Number
    errorSource = Err.Source
    errorDescription = Err.Description
    On Error Resume Next
    If fileNumber > 0 Then
        Close #fileNumber
    End If
    On Error GoTo 0
    Err.Raise errorNumber, errorSource, errorDescription
End Sub

Public Function ByteArraysMatch( _
    ByRef leftBytes() As Byte, _
    ByVal leftCount As Long, _
    ByRef rightBytes() As Byte, _
    ByVal rightCount As Long) As Boolean

    Dim index As Long

    If leftCount <> rightCount Then
        Exit Function
    End If

    For index = 0 To leftCount - 1
        If leftBytes(index) <> rightBytes(index) Then
            Exit Function
        End If
    Next index

    ByteArraysMatch = True
End Function

Public Function BytesPreviewHex( _
    ByRef bytes() As Byte, _
    ByVal byteCount As Long, _
    ByVal maximumCount As Long) As String

    Dim index As Long
    Dim result As String
    Dim shownCount As Long

    shownCount = byteCount
    If shownCount > maximumCount Then
        shownCount = maximumCount
    End If

    For index = 0 To shownCount - 1
        If Len(result) > 0 Then
            result = result & " "
        End If
        result = result & Right$("0" & Hex$(bytes(index)), 2)
    Next index

    If byteCount > shownCount Then
        result = result & " ..."
    End If
    BytesPreviewHex = result
End Function

Public Function ReadTextFile(ByVal filePath As String) As String
    Dim byteCount As Long
    Dim bytes() As Byte

    ReadAllBytes filePath, bytes, byteCount
    If byteCount = 0 Then
        ReadTextFile = vbNullString
    Else
        ReadTextFile = StrConv(bytes, vbUnicode)
    End If
End Function

Public Function SourceBodyFromExport(ByVal exportText As String) As String
    Dim index As Long
    Dim lineText As String
    Dim lines() As String
    Dim normalized As String
    Dim result As String

    normalized = Replace(exportText, vbCrLf, vbLf)
    normalized = Replace(normalized, vbCr, vbLf)
    lines = Split(normalized, vbLf)

    For index = LBound(lines) To UBound(lines)
        lineText = CStr(lines(index))
        If LCase$(Left$(LTrim$(lineText), 10)) <> "attribute " Then
            If Len(result) > 0 Then
                result = result & vbCrLf
            End If
            result = result & lineText
        End If
    Next index

    SourceBodyFromExport = NormalizeSourceText(result)
End Function

Public Function ReadComponentSource(ByVal component As Object) As String
    Dim lineCount As Long

    lineCount = component.CodeModule.CountOfLines
    If lineCount = 0 Then
        ReadComponentSource = vbNullString
    Else
        ReadComponentSource = _
            component.CodeModule.lines(1, lineCount)
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

Public Function OpenBookReadOnlyForCase( _
    ByVal filePath As String) As Workbook

    Dim errorDescription As String
    Dim errorNumber As Long
    Dim errorSource As String
    Dim previousEvents As Boolean

    EnsureFileExists filePath
    previousEvents = Application.EnableEvents

    On Error GoTo Failed
    Application.EnableEvents = False
    Set OpenBookReadOnlyForCase = Application.Workbooks.Open( _
        Filename:=filePath, _
        UpdateLinks:=0, _
        ReadOnly:=True, _
        AddToMru:=False, _
        IgnoreReadOnlyRecommended:=True, _
        Notify:=False)
    Application.EnableEvents = previousEvents
    Exit Function

Failed:
    errorNumber = Err.Number
    errorSource = Err.Source
    errorDescription = Err.Description
    On Error Resume Next
    Application.EnableEvents = previousEvents
    On Error GoTo 0
    Err.Raise errorNumber, errorSource, errorDescription
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

Public Function ErrorText( _
    ByVal errorNumber As Long, _
    ByVal errorDescription As String) As String

    ErrorText = _
        "Error " & CStr(errorNumber) & ": " & errorDescription
End Function

Private Sub EnsureFileExists(ByVal filePath As String)
    If Len(Dir$(filePath)) = 0 Then
        Err.Raise vbObjectError + 2604, _
            "MacroStudioValidation", _
            "Required fixture is unavailable: " & filePath
    End If
End Sub

Private Sub ValidateFixtureId(ByVal fixtureId As String)
    If fixtureId <> "01" And fixtureId <> "02" Then
        Err.Raise vbObjectError + 2605, _
            "MacroStudioValidation", _
            "Unknown fixture id: " & fixtureId
    End If
End Sub
