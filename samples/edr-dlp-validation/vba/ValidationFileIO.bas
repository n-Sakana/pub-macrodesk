Attribute VB_Name = "ValidationFileIO"
Option Explicit

Public Sub A1_ReadBinary_Plain()
    ExecuteBinaryReadCase _
        "A1", _
        "vba\FixturePlain.bas", _
        "plain harmless VBA source", _
        True
End Sub

Public Sub A2_ReadBinary_PtrSafeText()
    ExecuteBinaryReadCase _
        "A2", _
        "vba\FixturePtrSafe.bas", _
        "VBA source containing a static PtrSafe Sleep declaration", _
        True
End Sub

Public Sub A3_WriteBinaryCopy_Plain()
    ExecuteBinaryCopyCase _
        "A3", _
        "vba\FixturePlain.bas", _
        "A3_plain_binary_copy", _
        "plain harmless VBA source", _
        True
End Sub

Public Sub A4_WriteBinaryCopy_PtrSafeText()
    ExecuteBinaryCopyCase _
        "A4", _
        "vba\FixturePtrSafe.bas", _
        "A4_ptrsafe_binary_copy", _
        "VBA source containing a static PtrSafe Sleep declaration", _
        True
End Sub

Public Function ExecuteBinaryReadCase( _
    ByVal caseId As String, _
    ByVal relativeSourcePath As String, _
    ByVal fixtureDescription As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim bytes() As Byte
    Dim byteCount As Long
    Dim detailText As String
    Dim inputPath As String
    Dim startedAt As Date

    On Error GoTo Failed
    startedAt = Now
    inputPath = SampleFilePath(relativeSourcePath)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read the selected local fixture with VBA Open For Binary.", _
            inputPath, _
            "No file is written.", _
            "The fixture is read successfully and its byte count and " & _
                "visible preview are reported.") Then
            Exit Function
        End If
    End If

    ReadAllBytes inputPath, bytes, byteCount
    detailText = "Fixture: " & fixtureDescription & vbCrLf & _
        "Bytes read: " & CStr(byteCount) & vbCrLf & _
        "Preview:" & vbCrLf & BytesToText(bytes, byteCount)

    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, "(read only)", _
        "bytes=" & CStr(byteCount)
    If interactive Then
        ShowCaseResult caseId, True, inputPath, "(read only)", detailText
    End If
    ExecuteBinaryReadCase = True
    Exit Function

Failed:
    detailText = "Error " & CStr(Err.Number) & ": " & Err.Description
    RecordCaseResult _
        startedAt, caseId, "FAIL", inputPath, "(read only)", detailText
    If interactive Then
        ShowCaseResult caseId, False, inputPath, "(read only)", detailText
    End If
End Function

Public Function ExecuteBinaryCopyCase( _
    ByVal caseId As String, _
    ByVal relativeSourcePath As String, _
    ByVal outputPrefix As String, _
    ByVal fixtureDescription As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim copiedBytes() As Byte
    Dim copiedCount As Long
    Dim detailText As String
    Dim inputBytes() As Byte
    Dim inputCount As Long
    Dim inputPath As String
    Dim outputPath As String
    Dim startedAt As Date

    On Error GoTo Failed
    startedAt = Now
    inputPath = SampleFilePath(relativeSourcePath)
    outputPath = UniqueOutputPath(outputPrefix, ".bas")

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read the local fixture with Open For Binary, write the " & _
                "same bytes to a new copy, then read the copy back " & _
                "and compare every byte.", _
            inputPath, _
            outputPath, _
            "The new copy matches exactly. The input is never opened " & _
                "for writing and an existing output is never replaced.") Then
            Exit Function
        End If
    End If

    EnsureOutputFolder
    ReadAllBytes inputPath, inputBytes, inputCount
    WriteNewBytes outputPath, inputBytes, inputCount
    ReadAllBytes outputPath, copiedBytes, copiedCount

    If Not ByteArraysMatch( _
        inputBytes, inputCount, copiedBytes, copiedCount) Then
        Err.Raise vbObjectError + 2410, _
            "MacroStudioValidation", _
            "The new copy did not match the input byte for byte."
    End If

    detailText = "Fixture: " & fixtureDescription & vbCrLf & _
        "Bytes written: " & CStr(copiedCount) & vbCrLf & _
        "Verification: exact byte-for-byte match"
    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, outputPath, _
        "bytes=" & CStr(copiedCount) & "; exact_match=true"
    If interactive Then
        ShowCaseResult caseId, True, inputPath, outputPath, detailText
    End If
    ExecuteBinaryCopyCase = True
    Exit Function

Failed:
    detailText = "Error " & CStr(Err.Number) & ": " & Err.Description
    RecordCaseResult _
        startedAt, caseId, "FAIL", inputPath, outputPath, detailText
    If interactive Then
        ShowCaseResult caseId, False, inputPath, outputPath, detailText
    End If
End Function

Private Sub ReadAllBytes( _
    ByVal filePath As String, _
    ByRef bytes() As Byte, _
    ByRef byteCount As Long)

    Dim errorDescription As String
    Dim errorNumber As Long
    Dim errorSource As String
    Dim fileNumber As Integer

    On Error GoTo Failed
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

Private Sub WriteNewBytes( _
    ByVal filePath As String, _
    ByRef bytes() As Byte, _
    ByVal byteCount As Long)

    Dim errorDescription As String
    Dim errorNumber As Long
    Dim errorSource As String
    Dim fileNumber As Integer

    If Len(Dir$(filePath)) > 0 Then
        Err.Raise vbObjectError + 2411, _
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

Private Function ByteArraysMatch( _
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

Private Function BytesToText( _
    ByRef bytes() As Byte, _
    ByVal byteCount As Long) As String

    If byteCount = 0 Then
        BytesToText = "(empty fixture)"
    Else
        BytesToText = PreviewText(StrConv(bytes, vbUnicode), 600)
    End If
End Function
