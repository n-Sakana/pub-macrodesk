Attribute VB_Name = "RunnerDiagnosticCore"
Option Explicit
Option Private Module

Private Const DIAGNOSTIC_FOLDER_NAME As String = "diagnostic"
Private Const DIAGNOSTIC_LOG_NAME As String = "diagnostic-progress.tsv"
Private Const READ_OPEN_CLOSE As Long = 0
Private Const READ_ONE_BYTE As Long = 1
Private Const READ_UP_TO_4096 As Long = 2
Private Const READ_ALL As Long = 3

Private mSessionId As String

Public Sub AppendDiagnosticStage( _
    ByVal caseId As String, _
    ByVal itemId As String, _
    ByVal stageName As String, _
    ByVal resultText As String, _
    ByVal detailText As String)

    Dim errorDescription As String
    Dim errorNumber As Long
    Dim errorSource As String
    Dim fileNumber As Integer
    Dim isNewFile As Boolean
    Dim logPath As String

    On Error GoTo Failed
    EnsureOutputFolder
    logPath = DiagnosticLogPath()
    isNewFile = (Len(Dir$(logPath)) = 0)

    fileNumber = FreeFile
    Open logPath For Append Access Write As #fileNumber
    If isNewFile Then
        Print #fileNumber, _
            "timestamp" & vbTab & _
            "session" & vbTab & _
            "case" & vbTab & _
            "item" & vbTab & _
            "stage" & vbTab & _
            "result" & vbTab & _
            "detail"
    End If
    Print #fileNumber, _
        DiagnosticTimestamp() & vbTab & _
        SafeLogField(DiagnosticSessionId()) & vbTab & _
        SafeLogField(caseId) & vbTab & _
        SafeLogField(itemId) & vbTab & _
        SafeLogField(stageName) & vbTab & _
        SafeLogField(resultText) & vbTab & _
        SafeLogField(detailText)
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

Public Function DiagnosticLogPath() As String
    DiagnosticLogPath = _
        OutputFolderPath() & Application.PathSeparator & _
        DIAGNOSTIC_LOG_NAME
End Function

Public Sub StartNewDiagnosticSession()
    mSessionId = NewSessionId()
    AppendDiagnosticStage _
        "X00", "-", "SESSION_START", "OK", _
        "log=" & DiagnosticLogPath()
End Sub

Public Function ExecuteDiagnosticExistenceCase( _
    ByVal caseId As String, _
    ByVal itemId As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim detailText As String
    Dim errorDescription As String
    Dim errorNumber As Long
    Dim inputPath As String
    Dim startedAt As Date

    On Error GoTo Failed
    inputPath = DiagnosticItemPath(itemId)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Record expected metadata, then check only whether the " & _
                "selected neutral item exists and report its size.", _
            inputPath, _
            DiagnosticLogPath(), _
            "No content is opened or read. Presence and size are " & _
                "written to the external progress log.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    AppendDiagnosticStage _
        caseId, itemId, "TEST_START", "OK", _
        "operation=existence_only"
    CheckItemMetadata caseId, itemId, inputPath
    detailText = _
        "item=" & itemId & _
        "; exists=true; size=" & CStr(ExpectedItemSize(itemId)) & _
        "; content_read=false"
    AppendDiagnosticStage _
        caseId, itemId, "CASE_END", "PASS", detailText
    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, _
        DiagnosticLogPath(), detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, inputPath, DiagnosticLogPath(), detailText
    End If
    ExecuteDiagnosticExistenceCase = True
    Exit Function

Failed:
    errorNumber = Err.Number
    errorDescription = Err.Description
    detailText = FinishDiagnosticFailure( _
        startedAt, caseId, itemId, inputPath, _
        DiagnosticLogPath(), errorNumber, errorDescription, interactive)
End Function

Public Function ExecuteDiagnosticGetCase( _
    ByVal caseId As String, _
    ByVal itemId As String, _
    ByVal readMode As Long, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim actualHash As String
    Dim allBytes() As Byte
    Dim blockBytes() As Byte
    Dim blockCount As Long
    Dim byteCount As Long
    Dim detailText As String
    Dim errorDescription As String
    Dim errorNumber As Long
    Dim fileNumber As Integer
    Dim inputPath As String
    Dim isOpen As Boolean
    Dim oneByte As Byte
    Dim openSize As Long
    Dim startedAt As Date

    On Error GoTo Failed
    ValidateReadMode readMode
    inputPath = DiagnosticItemPath(itemId)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            GetReadActionText(readMode), _
            inputPath, _
            DiagnosticLogPath(), _
            "Every completed boundary is appended and closed in the " & _
                "external log. No output copy is created.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    AppendDiagnosticStage _
        caseId, itemId, "TEST_START", "OK", _
        "operation=" & GetReadModeName(readMode)
    byteCount = CheckItemMetadata(caseId, itemId, inputPath)

    AppendDiagnosticStage _
        caseId, itemId, "OPEN_ATTEMPT", "START", _
        "method=binary_get"
    fileNumber = FreeFile
    Open inputPath For Binary Access Read Lock Read As #fileNumber
    isOpen = True
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_BINARY_OK", "OK", _
        "file_open=true"
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_SIZE_CHECK_START", "START", _
        "method=lof"
    openSize = LOF(fileNumber)
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_SIZE_RESULT", "OK", _
        "actual_size=" & CStr(openSize) & _
        "; expected_size=" & CStr(byteCount) & _
        "; expected_match=" & BooleanText(openSize = byteCount)
    If openSize <> byteCount Then
        Err.Raise vbObjectError + 2683, _
            "MacroStudioValidation", _
            "The opened item size changed after the existence check."
    End If

    Select Case readMode
        Case READ_OPEN_CLOSE
            ' Intentionally no content access.

        Case READ_ONE_BYTE
            Get #fileNumber, 1, oneByte
            AppendDiagnosticStage _
                caseId, itemId, "READ_1_BYTE_OK", "OK", _
                "bytes=1"

        Case READ_UP_TO_4096
            blockCount = MinimumLong(byteCount, 4096)
            ReDim blockBytes(0 To blockCount - 1)
            Get #fileNumber, 1, blockBytes
            AppendDiagnosticStage _
                caseId, itemId, "READ_UP_TO_4096_OK", "OK", _
                "bytes=" & CStr(blockCount)

        Case READ_ALL
            Get #fileNumber, 1, oneByte
            AppendDiagnosticStage _
                caseId, itemId, "READ_1_BYTE_OK", "OK", _
                "bytes=1"

            blockCount = MinimumLong(byteCount, 4096)
            ReDim blockBytes(0 To blockCount - 1)
            Get #fileNumber, 1, blockBytes
            AppendDiagnosticStage _
                caseId, itemId, "READ_UP_TO_4096_OK", "OK", _
                "bytes=" & CStr(blockCount)

            ReDim allBytes(0 To byteCount - 1)
            Get #fileNumber, 1, allBytes
            AppendDiagnosticStage _
                caseId, itemId, "READ_ALL_OK", "OK", _
                "bytes=" & CStr(byteCount)
    End Select

    Close #fileNumber
    isOpen = False
    AppendDiagnosticStage _
        caseId, itemId, "CLOSE_OK", "OK", _
        "method=binary_get"

    If readMode = READ_ALL Then
        AppendDiagnosticStage _
            caseId, itemId, "ANALYSIS_START", "START", _
            "method=pure_vba_sha256"
        actualHash = Sha256HexBytes(allBytes, byteCount)
        AppendDiagnosticStage _
            caseId, itemId, "ANALYSIS_OK", "OK", _
            "actual_sha256=" & actualHash & _
            "; expected_match=" & _
                BooleanText(actualHash = ExpectedItemHash(itemId))
        If actualHash <> ExpectedItemHash(itemId) Then
            Err.Raise vbObjectError + 2670, _
                "MacroStudioValidation", _
                "The content hash did not match the expected metadata."
        End If
    End If

    detailText = _
        "item=" & itemId & _
        "; operation=" & GetReadModeName(readMode) & _
        "; size=" & CStr(byteCount)
    If readMode = READ_ALL Then
        detailText = detailText & _
            "; sha256=" & actualHash & _
            "; expected_match=true"
    End If
    AppendDiagnosticStage _
        caseId, itemId, "CASE_END", "PASS", detailText
    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, _
        DiagnosticLogPath(), detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, inputPath, DiagnosticLogPath(), detailText
    End If
    ExecuteDiagnosticGetCase = True
    Exit Function

Failed:
    errorNumber = Err.Number
    errorDescription = Err.Description
    If isOpen Then
        On Error Resume Next
        Close #fileNumber
        If Err.Number = 0 Then
            AppendDiagnosticStage _
                caseId, itemId, "CLOSE_AFTER_ERROR", "OK", _
                "method=binary_get"
        End If
        On Error GoTo 0
    End If
    detailText = FinishDiagnosticFailure( _
        startedAt, caseId, itemId, inputPath, _
        DiagnosticLogPath(), errorNumber, errorDescription, interactive)
End Function

Public Function ExecuteDiagnosticInputBCase( _
    ByVal caseId As String, _
    ByVal itemId As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim byteCount As Long
    Dim chunk As String
    Dim detailText As String
    Dim errorDescription As String
    Dim errorNumber As Long
    Dim fileNumber As Integer
    Dim inputPath As String
    Dim isOpen As Boolean
    Dim openSize As Long
    Dim readCount As Long
    Dim startedAt As Date

    On Error GoTo Failed
    inputPath = DiagnosticItemPath(itemId)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Open the selected neutral item with VBA binary file I/O " & _
                "and read at most 4 KiB with InputB$ instead of Get.", _
            inputPath, _
            DiagnosticLogPath(), _
            "This one comparison distinguishes the Get/Byte-array " & _
                "path from another in-process VBA read primitive.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    AppendDiagnosticStage _
        caseId, itemId, "TEST_START", "OK", _
        "operation=inputb_up_to_4096"
    byteCount = CheckItemMetadata(caseId, itemId, inputPath)
    readCount = MinimumLong(byteCount, 4096)

    AppendDiagnosticStage _
        caseId, itemId, "OPEN_ATTEMPT", "START", _
        "method=binary_inputb"
    fileNumber = FreeFile
    Open inputPath For Binary Access Read Lock Read As #fileNumber
    isOpen = True
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_BINARY_OK", "OK", _
        "file_open=true"
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_SIZE_CHECK_START", "START", _
        "method=lof"
    openSize = LOF(fileNumber)
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_SIZE_RESULT", "OK", _
        "actual_size=" & CStr(openSize) & _
        "; expected_size=" & CStr(byteCount) & _
        "; expected_match=" & BooleanText(openSize = byteCount)
    If openSize <> byteCount Then
        Err.Raise vbObjectError + 2684, _
            "MacroStudioValidation", _
            "The opened item size changed after the existence check."
    End If

    chunk = InputB$(readCount, fileNumber)
    AppendDiagnosticStage _
        caseId, itemId, "INPUTB_READ_UP_TO_4096_OK", "OK", _
        "bytes=" & CStr(LenB(chunk))

    Close #fileNumber
    isOpen = False
    AppendDiagnosticStage _
        caseId, itemId, "CLOSE_OK", "OK", _
        "method=binary_inputb"

    AppendDiagnosticStage _
        caseId, itemId, "ANALYSIS_START", "START", _
        "method=byte_length"
    If LenB(chunk) <> readCount Then
        Err.Raise vbObjectError + 2671, _
            "MacroStudioValidation", _
            "InputB$ returned an unexpected byte count."
    End If
    AppendDiagnosticStage _
        caseId, itemId, "ANALYSIS_OK", "OK", _
        "bytes=" & CStr(LenB(chunk)) & "; expected_match=true"

    detailText = _
        "item=" & itemId & _
        "; operation=inputb_up_to_4096" & _
        "; bytes=" & CStr(LenB(chunk))
    AppendDiagnosticStage _
        caseId, itemId, "CASE_END", "PASS", detailText
    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, _
        DiagnosticLogPath(), detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, inputPath, DiagnosticLogPath(), detailText
    End If
    ExecuteDiagnosticInputBCase = True
    Exit Function

Failed:
    errorNumber = Err.Number
    errorDescription = Err.Description
    If isOpen Then
        On Error Resume Next
        Close #fileNumber
        If Err.Number = 0 Then
            AppendDiagnosticStage _
                caseId, itemId, "CLOSE_AFTER_ERROR", "OK", _
                "method=binary_inputb"
        End If
        On Error GoTo 0
    End If
    detailText = FinishDiagnosticFailure( _
        startedAt, caseId, itemId, inputPath, _
        DiagnosticLogPath(), errorNumber, errorDescription, interactive)
End Function

Public Function ExecuteDiagnosticRebuildCase( _
    ByVal caseId As String, _
    ByVal itemId As String, _
    ByVal outputExtension As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim actualHash As String
    Dim allBytes() As Byte
    Dim blockBytes() As Byte
    Dim blockCount As Long
    Dim byteCount As Long
    Dim detailText As String
    Dim errorDescription As String
    Dim errorNumber As Long
    Dim inputFileNumber As Integer
    Dim inputIsOpen As Boolean
    Dim inputPath As String
    Dim oneByte As Byte
    Dim openSize As Long
    Dim outputFileNumber As Integer
    Dim outputIsOpen As Boolean
    Dim outputPath As String
    Dim outputHash As String
    Dim startedAt As Date
    Dim verifyBytes() As Byte
    Dim verifyCount As Long
    Dim verifyFileNumber As Integer
    Dim verifyIsOpen As Boolean

    On Error GoTo Failed
    ValidateOutputExtension outputExtension
    inputPath = DiagnosticItemPath(itemId)
    EnsureOutputFolder
    outputPath = UniqueOutputPath( _
        caseId & "_item-" & itemId & "_rebuild", _
        outputExtension)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read the selected neutral item in staged binary steps, " & _
                "rebuild it only as a new output file, then reopen and " & _
                "verify it byte for byte.", _
            inputPath, _
            outputPath & " and " & DiagnosticLogPath(), _
            "The input is never written. A partial output is retained " & _
                "as evidence if Excel returns an error.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    AppendDiagnosticStage _
        caseId, itemId, "TEST_START", "OK", _
        "operation=rebuild; output=" & outputPath
    byteCount = CheckItemMetadata(caseId, itemId, inputPath)

    AppendDiagnosticStage _
        caseId, itemId, "OPEN_ATTEMPT", "START", _
        "method=binary_get"
    inputFileNumber = FreeFile
    Open inputPath For Binary Access Read Lock Read As #inputFileNumber
    inputIsOpen = True
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_BINARY_OK", "OK", _
        "file_open=true"
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_SIZE_CHECK_START", "START", _
        "method=lof"
    openSize = LOF(inputFileNumber)
    AppendDiagnosticStage _
        caseId, itemId, "OPEN_SIZE_RESULT", "OK", _
        "actual_size=" & CStr(openSize) & _
        "; expected_size=" & CStr(byteCount) & _
        "; expected_match=" & BooleanText(openSize = byteCount)
    If openSize <> byteCount Then
        Err.Raise vbObjectError + 2685, _
            "MacroStudioValidation", _
            "The opened item size changed after the existence check."
    End If

    Get #inputFileNumber, 1, oneByte
    AppendDiagnosticStage _
        caseId, itemId, "READ_1_BYTE_OK", "OK", "bytes=1"

    blockCount = MinimumLong(byteCount, 4096)
    ReDim blockBytes(0 To blockCount - 1)
    Get #inputFileNumber, 1, blockBytes
    AppendDiagnosticStage _
        caseId, itemId, "READ_UP_TO_4096_OK", "OK", _
        "bytes=" & CStr(blockCount)

    ReDim allBytes(0 To byteCount - 1)
    Get #inputFileNumber, 1, allBytes
    AppendDiagnosticStage _
        caseId, itemId, "READ_ALL_OK", "OK", _
        "bytes=" & CStr(byteCount)

    Close #inputFileNumber
    inputIsOpen = False
    AppendDiagnosticStage _
        caseId, itemId, "CLOSE_OK", "OK", _
        "method=binary_get"

    AppendDiagnosticStage _
        caseId, itemId, "ANALYSIS_START", "START", _
        "method=pure_vba_sha256"
    actualHash = Sha256HexBytes(allBytes, byteCount)
    AppendDiagnosticStage _
        caseId, itemId, "ANALYSIS_OK", "OK", _
        "actual_sha256=" & actualHash & _
        "; expected_match=" & _
            BooleanText(actualHash = ExpectedItemHash(itemId))
    If actualHash <> ExpectedItemHash(itemId) Then
        Err.Raise vbObjectError + 2672, _
            "MacroStudioValidation", _
            "The source content hash did not match expected metadata."
    End If

    If Len(Dir$(outputPath)) > 0 Then
        Err.Raise vbObjectError + 2673, _
            "MacroStudioValidation", _
            "Refusing to replace an existing diagnostic output."
    End If

    AppendDiagnosticStage _
        caseId, itemId, "OUTPUT_OPEN_ATTEMPT", "START", _
        "output=" & outputPath
    outputFileNumber = FreeFile
    Open outputPath For Binary Access Write Lock Write As #outputFileNumber
    outputIsOpen = True
    AppendDiagnosticStage _
        caseId, itemId, "OUTPUT_OPEN_BINARY_OK", "OK", _
        "output=" & outputPath

    Put #outputFileNumber, 1, oneByte
    AppendDiagnosticStage _
        caseId, itemId, "WRITE_1_BYTE_OK", "OK", "bytes=1"

    Put #outputFileNumber, 1, blockBytes
    AppendDiagnosticStage _
        caseId, itemId, "WRITE_UP_TO_4096_OK", "OK", _
        "bytes=" & CStr(blockCount)

    Put #outputFileNumber, 1, allBytes
    AppendDiagnosticStage _
        caseId, itemId, "WRITE_ALL_OK", "OK", _
        "bytes=" & CStr(byteCount)

    Close #outputFileNumber
    outputIsOpen = False
    AppendDiagnosticStage _
        caseId, itemId, "OUTPUT_CLOSE_OK", "OK", _
        "bytes=" & CStr(byteCount)

    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_OPEN_ATTEMPT", "START", _
        "output=" & outputPath
    verifyFileNumber = FreeFile
    Open outputPath For Binary Access Read Lock Read As #verifyFileNumber
    verifyIsOpen = True
    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_OPEN_BINARY_OK", "OK", _
        "file_open=true"

    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_SIZE_CHECK_START", "START", _
        "method=lof"
    verifyCount = LOF(verifyFileNumber)
    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_SIZE_RESULT", "OK", _
        "actual_size=" & CStr(verifyCount) & _
        "; expected_size=" & CStr(byteCount) & _
        "; expected_match=" & _
            BooleanText(verifyCount = byteCount)
    If verifyCount <> byteCount Then
        Err.Raise vbObjectError + 2686, _
            "MacroStudioValidation", _
            "The rebuilt output size did not match the source."
    End If
    ReDim verifyBytes(0 To verifyCount - 1)
    Get #verifyFileNumber, 1, verifyBytes
    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_READ_ALL_OK", "OK", _
        "bytes=" & CStr(verifyCount)

    Close #verifyFileNumber
    verifyIsOpen = False
    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_CLOSE_OK", "OK", _
        "output=" & outputPath

    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_ANALYSIS_START", "START", _
        "method=pure_vba_sha256_and_byte_compare"
    outputHash = Sha256HexBytes(verifyBytes, verifyCount)
    If Not ByteArraysMatch( _
        allBytes, byteCount, verifyBytes, verifyCount) Then
        Err.Raise vbObjectError + 2674, _
            "MacroStudioValidation", _
            "The rebuilt output did not match the source byte for byte."
    End If
    AppendDiagnosticStage _
        caseId, itemId, "VERIFY_ANALYSIS_OK", "OK", _
        "sha256=" & outputHash & _
        "; exact_match=true"

    detailText = _
        "item=" & itemId & _
        "; bytes=" & CStr(byteCount) & _
        "; sha256=" & actualHash & _
        "; exact_match=true"
    AppendDiagnosticStage _
        caseId, itemId, "CASE_END", "PASS", detailText
    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, outputPath, detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, inputPath, outputPath, detailText
    End If
    ExecuteDiagnosticRebuildCase = True
    Exit Function

Failed:
    errorNumber = Err.Number
    errorDescription = Err.Description
    On Error Resume Next
    If inputIsOpen Then
        Close #inputFileNumber
        If Err.Number = 0 Then
            AppendDiagnosticStage _
                caseId, itemId, "CLOSE_AFTER_ERROR", "OK", _
                "stream=input"
        End If
    End If
    Err.Clear
    If outputIsOpen Then
        Close #outputFileNumber
        If Err.Number = 0 Then
            AppendDiagnosticStage _
                caseId, itemId, "OUTPUT_CLOSE_AFTER_ERROR", "OK", _
                "output=" & outputPath
        End If
    End If
    Err.Clear
    If verifyIsOpen Then
        Close #verifyFileNumber
        If Err.Number = 0 Then
            AppendDiagnosticStage _
                caseId, itemId, "VERIFY_CLOSE_AFTER_ERROR", "OK", _
                "output=" & outputPath
        End If
    End If
    On Error GoTo 0
    detailText = FinishDiagnosticFailure( _
        startedAt, caseId, itemId, inputPath, outputPath, _
        errorNumber, errorDescription, interactive)
End Function

Private Function BooleanText(ByVal value As Boolean) As String
    If value Then
        BooleanText = "true"
    Else
        BooleanText = "false"
    End If
End Function

Private Function CheckItemMetadata( _
    ByVal caseId As String, _
    ByVal itemId As String, _
    ByVal inputPath As String) As Long

    Dim actualSize As Long
    Dim exists As Boolean

    AppendDiagnosticStage _
        caseId, itemId, "EXPECTED_METADATA", "OK", _
        "expected_size=" & CStr(ExpectedItemSize(itemId)) & _
        "; expected_sha256=" & ExpectedItemHash(itemId)
    AppendDiagnosticStage _
        caseId, itemId, "EXISTS_CHECK_START", "START", _
        "path=" & inputPath

    exists = (Len(Dir$(inputPath)) > 0)
    AppendDiagnosticStage _
        caseId, itemId, "EXISTS_RESULT", _
        IIf(exists, "PRESENT", "MISSING"), _
        "path=" & inputPath
    If Not exists Then
        Err.Raise vbObjectError + 2675, _
            "MacroStudioValidation", _
            "The selected diagnostic item is unavailable."
    End If

    actualSize = FileLen(inputPath)
    AppendDiagnosticStage _
        caseId, itemId, "SIZE_RESULT", "OK", _
        "actual_size=" & CStr(actualSize) & _
        "; expected_size=" & CStr(ExpectedItemSize(itemId)) & _
        "; expected_match=" & _
            BooleanText(actualSize = ExpectedItemSize(itemId))
    If actualSize <> ExpectedItemSize(itemId) Then
        Err.Raise vbObjectError + 2676, _
            "MacroStudioValidation", _
            "The selected item size did not match expected metadata."
    End If

    CheckItemMetadata = actualSize
End Function

Private Function DiagnosticItemPath(ByVal itemId As String) As String
    Select Case itemId
        Case "01"
            DiagnosticItemPath = FixtureBookPath("02")
        Case "02"
            DiagnosticItemPath = SampleFilePath( _
                "fixtures" & Application.PathSeparator & _
                DIAGNOSTIC_FOLDER_NAME & Application.PathSeparator & _
                "item-02.dat")
        Case "03"
            DiagnosticItemPath = SampleFilePath( _
                "fixtures" & Application.PathSeparator & _
                DIAGNOSTIC_FOLDER_NAME & Application.PathSeparator & _
                "item-03.dat")
        Case "04"
            DiagnosticItemPath = SampleFilePath( _
                "fixtures" & Application.PathSeparator & _
                DIAGNOSTIC_FOLDER_NAME & Application.PathSeparator & _
                "item-04.bas")
        Case Else
            Err.Raise vbObjectError + 2677, _
                "MacroStudioValidation", _
                "Unknown diagnostic item id: " & itemId
    End Select
End Function

Private Function DiagnosticSessionId() As String
    If Len(mSessionId) = 0 Then
        mSessionId = NewSessionId()
    End If
    DiagnosticSessionId = mSessionId
End Function

Private Function DiagnosticTimestamp() As String
    Dim milliseconds As Long

    milliseconds = CLng( _
        Fix((Timer - Fix(Timer)) * 1000#))
    DiagnosticTimestamp = _
        Format$(Now, "yyyy-mm-dd hh:nn:ss") & "." & _
        Right$("000" & CStr(milliseconds), 3)
End Function

Private Function ExpectedItemHash(ByVal itemId As String) As String
    Select Case itemId
        Case "01", "02"
            ExpectedItemHash = _
                "D8C4EEF261568D5EC42735A153B0192D" & _
                "5012A66CF6F5C4BA52E800430263CB09"
        Case "03"
            ExpectedItemHash = _
                "9A3ED06A0D19DFF34DDCFA9BA70A0B9" & _
                "CABF64F66049E4DD210CB9CDC3BA5DE42"
        Case "04"
            ExpectedItemHash = _
                "C54C7F13A5A004FDDE401B4A7C3B58D" & _
                "96290A28FF8BEF83FC502DBD36975BCFE"
        Case Else
            Err.Raise vbObjectError + 2678, _
                "MacroStudioValidation", _
                "Unknown diagnostic item id: " & itemId
    End Select
End Function

Private Function ExpectedItemSize(ByVal itemId As String) As Long
    Select Case itemId
        Case "01", "02"
            ExpectedItemSize = 11847
        Case "03"
            ExpectedItemSize = 10752
        Case "04"
            ExpectedItemSize = 232
        Case Else
            Err.Raise vbObjectError + 2679, _
                "MacroStudioValidation", _
                "Unknown diagnostic item id: " & itemId
    End Select
End Function

Private Function FinishDiagnosticFailure( _
    ByVal startedAt As Date, _
    ByVal caseId As String, _
    ByVal itemId As String, _
    ByVal inputText As String, _
    ByVal outputText As String, _
    ByVal errorNumber As Long, _
    ByVal errorDescription As String, _
    ByVal interactive As Boolean) As String

    Dim detailText As String

    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ErrorText(errorNumber, errorDescription)

    On Error Resume Next
    AppendDiagnosticStage _
        caseId, itemId, "ERROR", "FAIL", detailText
    AppendDiagnosticStage _
        caseId, itemId, "CASE_END", "FAIL", detailText
    RecordCaseResult _
        startedAt, caseId, "FAIL", inputText, outputText, detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, inputText, outputText, detailText
    End If
    On Error GoTo 0

    FinishDiagnosticFailure = detailText
End Function

Private Function GetReadActionText(ByVal readMode As Long) As String
    Select Case readMode
        Case READ_OPEN_CLOSE
            GetReadActionText = _
                "Open the selected neutral item for binary reading " & _
                "and close it without reading content."
        Case READ_ONE_BYTE
            GetReadActionText = _
                "Open the selected neutral item for binary reading, " & _
                "read exactly one byte with Get, and close it."
        Case READ_UP_TO_4096
            GetReadActionText = _
                "Open the selected neutral item for binary reading, " & _
                "read at most 4 KiB with Get, and close it."
        Case READ_ALL
            GetReadActionText = _
                "Open the selected neutral item for binary reading, " & _
                "record the 1-byte, 4-KiB, and complete-read boundaries, " & _
                "close it, then calculate a pure VBA SHA-256."
    End Select
End Function

Private Function GetReadModeName(ByVal readMode As Long) As String
    Select Case readMode
        Case READ_OPEN_CLOSE
            GetReadModeName = "open_close"
        Case READ_ONE_BYTE
            GetReadModeName = "get_1_byte"
        Case READ_UP_TO_4096
            GetReadModeName = "get_up_to_4096"
        Case READ_ALL
            GetReadModeName = "get_all_and_hash"
    End Select
End Function

Private Function MinimumLong( _
    ByVal leftValue As Long, _
    ByVal rightValue As Long) As Long

    If leftValue < rightValue Then
        MinimumLong = leftValue
    Else
        MinimumLong = rightValue
    End If
End Function

Private Function NewSessionId() As String
    NewSessionId = _
        Format$(Now, "yyyymmdd_hhnnss") & "_" & _
        Right$("00000000" & Hex$(CLng(Timer * 100#)), 8)
End Function

Private Function SafeLogField(ByVal value As String) As String
    Dim result As String

    result = Replace(value, vbTab, " ")
    result = Replace(result, vbCrLf, " | ")
    result = Replace(result, vbCr, " | ")
    result = Replace(result, vbLf, " | ")
    SafeLogField = result
End Function

Private Sub ValidateOutputExtension(ByVal outputExtension As String)
    If outputExtension <> ".dat" And outputExtension <> ".xlsm" Then
        Err.Raise vbObjectError + 2680, _
            "MacroStudioValidation", _
            "Unsupported diagnostic output extension."
    End If
End Sub

Private Sub ValidateReadMode(ByVal readMode As Long)
    If readMode < READ_OPEN_CLOSE Or readMode > READ_ALL Then
        Err.Raise vbObjectError + 2681, _
            "MacroStudioValidation", _
            "Unknown diagnostic read mode."
    End If
End Sub
