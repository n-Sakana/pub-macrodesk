Attribute VB_Name = "RunnerBinary"
Option Explicit

Public Sub A1_ReadClosedFixture01()
    ExecuteBinaryReadCase "A1", "01", True
End Sub

Public Sub A2_ReadClosedFixture02()
    ExecuteBinaryReadCase "A2", "02", True
End Sub

Public Sub B1_CopyClosedFixture01()
    ExecuteBinaryCopyCase "B1", "01", True
End Sub

Public Sub B2_CopyClosedFixture02()
    ExecuteBinaryCopyCase "B2", "02", True
End Sub

Public Function ExecuteBinaryReadCase( _
    ByVal caseId As String, _
    ByVal fixtureId As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim byteCount As Long
    Dim bytes() As Byte
    Dim detailText As String
    Dim inputPath As String
    Dim startedAt As Date

    On Error GoTo Failed
    inputPath = FixtureBookPath(fixtureId)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read the selected closed fixture with Open For Binary. " & _
                "Excel does not open the fixture as a workbook.", _
            inputPath, _
            "(read only)", _
            "The byte count and first bytes are reported. No output " & _
                "file is created.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    ReadAllBytes inputPath, bytes, byteCount
    detailText = _
        "fixture=" & fixtureId & _
        "; bytes=" & CStr(byteCount) & _
        "; first_bytes=" & BytesPreviewHex(bytes, byteCount, 16)

    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, "(read only)", _
        detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, inputPath, "(read only)", detailText
    End If
    ExecuteBinaryReadCase = True
    Exit Function

Failed:
    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ErrorText(Err.Number, Err.Description)
    RecordCaseResult _
        startedAt, caseId, "FAIL", inputPath, "(read only)", _
        detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, inputPath, "(read only)", detailText
    End If
End Function

Public Function ExecuteBinaryCopyCase( _
    ByVal caseId As String, _
    ByVal fixtureId As String, _
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
    inputPath = FixtureBookPath(fixtureId)
    outputPath = UniqueOutputPath( _
        caseId & "_fixture-" & fixtureId & "_binary-copy", _
        ".xlsm")

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read the selected closed fixture as bytes, write the " & _
                "same bytes to a new output copy, then read the copy " & _
                "back and compare every byte.", _
            inputPath, _
            outputPath, _
            "The new copy matches byte for byte. The input is never " & _
                "opened for writing and existing output is not replaced.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    EnsureOutputFolder
    ReadAllBytes inputPath, inputBytes, inputCount
    WriteNewBytes outputPath, inputBytes, inputCount
    ReadAllBytes outputPath, copiedBytes, copiedCount

    If Not ByteArraysMatch( _
        inputBytes, inputCount, copiedBytes, copiedCount) Then
        Err.Raise vbObjectError + 2610, _
            "MacroStudioValidation", _
            "The output copy did not match the input byte for byte."
    End If

    detailText = _
        "fixture=" & fixtureId & _
        "; bytes=" & CStr(copiedCount) & _
        "; exact_match=true"
    RecordCaseResult _
        startedAt, caseId, "PASS", inputPath, outputPath, detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, inputPath, outputPath, detailText
    End If
    ExecuteBinaryCopyCase = True
    Exit Function

Failed:
    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ErrorText(Err.Number, Err.Description)
    RecordCaseResult _
        startedAt, caseId, "FAIL", inputPath, outputPath, detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, inputPath, outputPath, detailText
    End If
End Function
