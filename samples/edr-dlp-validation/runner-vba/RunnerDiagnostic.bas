Attribute VB_Name = "RunnerDiagnostic"
Option Explicit

Public Sub X00_StartDiagnosticSession()
    StartNewDiagnosticSession
    MsgBox _
        "A new append-only diagnostic session boundary was recorded." & _
        vbCrLf & vbCrLf & DiagnosticLogPath(), _
        vbInformation, _
        "MacroStudio diagnostic session"
End Sub

Public Sub X01_Item01_ExistenceOnly()
    ExecuteDiagnosticExistenceCase "X01", "01", True
End Sub

Public Sub X02_Item02_ExistenceOnly()
    ExecuteDiagnosticExistenceCase "X02", "02", True
End Sub

Public Sub X03_Item03_ExistenceOnly()
    ExecuteDiagnosticExistenceCase "X03", "03", True
End Sub

Public Sub X04_Item04_ExistenceOnly()
    ExecuteDiagnosticExistenceCase "X04", "04", True
End Sub

Public Sub X05_Item01_OpenClose()
    ExecuteDiagnosticGetCase "X05", "01", 0, True
End Sub

Public Sub X06_Item02_OpenClose()
    ExecuteDiagnosticGetCase "X06", "02", 0, True
End Sub

Public Sub X07_Item03_OpenClose()
    ExecuteDiagnosticGetCase "X07", "03", 0, True
End Sub

Public Sub X08_Item04_OpenClose()
    ExecuteDiagnosticGetCase "X08", "04", 0, True
End Sub

Public Sub X09_Item01_GetOneByte()
    ExecuteDiagnosticGetCase "X09", "01", 1, True
End Sub

Public Sub X10_Item02_GetOneByte()
    ExecuteDiagnosticGetCase "X10", "02", 1, True
End Sub

Public Sub X11_Item03_GetOneByte()
    ExecuteDiagnosticGetCase "X11", "03", 1, True
End Sub

Public Sub X12_Item04_GetOneByte()
    ExecuteDiagnosticGetCase "X12", "04", 1, True
End Sub

Public Sub X13_Item01_GetUpTo4096()
    ExecuteDiagnosticGetCase "X13", "01", 2, True
End Sub

Public Sub X14_Item02_GetUpTo4096()
    ExecuteDiagnosticGetCase "X14", "02", 2, True
End Sub

Public Sub X15_Item03_GetUpTo4096()
    ExecuteDiagnosticGetCase "X15", "03", 2, True
End Sub

Public Sub X16_Item04_GetUpTo4096()
    ExecuteDiagnosticGetCase "X16", "04", 2, True
End Sub

Public Sub X17_Item01_GetAllAndHash()
    ExecuteDiagnosticGetCase "X17", "01", 3, True
End Sub

Public Sub X18_Item02_GetAllAndHash()
    ExecuteDiagnosticGetCase "X18", "02", 3, True
End Sub

Public Sub X19_Item03_GetAllAndHash()
    ExecuteDiagnosticGetCase "X19", "03", 3, True
End Sub

Public Sub X20_Item04_GetAllAndHash()
    ExecuteDiagnosticGetCase "X20", "04", 3, True
End Sub

Public Sub X21_Item01_InputBUpTo4096()
    ExecuteDiagnosticInputBCase "X21", "01", True
End Sub

Public Sub X22_Item02_InputBUpTo4096()
    ExecuteDiagnosticInputBCase "X22", "02", True
End Sub

Public Sub X23_Item03_InputBUpTo4096()
    ExecuteDiagnosticInputBCase "X23", "03", True
End Sub

Public Sub X24_Item04_InputBUpTo4096()
    ExecuteDiagnosticInputBCase "X24", "04", True
End Sub

Public Sub X25_Item01_RebuildNeutral()
    ExecuteDiagnosticRebuildCase "X25", "01", ".dat", True
End Sub

Public Sub X26_Item01_RebuildBookExtension()
    ExecuteDiagnosticRebuildCase "X26", "01", ".xlsm", True
End Sub

Public Sub X27_Item02_RebuildNeutral()
    ExecuteDiagnosticRebuildCase "X27", "02", ".dat", True
End Sub

Public Sub X28_Item03_RebuildNeutral()
    ExecuteDiagnosticRebuildCase "X28", "03", ".dat", True
End Sub

Public Sub X29_Item04_RebuildNeutral()
    ExecuteDiagnosticRebuildCase "X29", "04", ".dat", True
End Sub

Public Sub X30_VerifyHashEngine()
    Dim detailText As String
    Dim startedAt As Date

    On Error GoTo Failed
    startedAt = Now
    AppendDiagnosticStage _
        "X30", "-", "TEST_START", "OK", _
        "operation=hash_self_test; fixture_access=false"
    AppendDiagnosticStage _
        "X30", "-", "ANALYSIS_START", "START", _
        "vectors=empty_and_three_bytes"
    If Not Sha256SelfTest() Then
        Err.Raise vbObjectError + 2682, _
            "MacroStudioValidation", _
            "The pure VBA hash self-test did not match known vectors."
    End If
    detailText = _
        "hash_self_test=true; fixture_access=false"
    AppendDiagnosticStage _
        "X30", "-", "ANALYSIS_OK", "OK", detailText
    AppendDiagnosticStage _
        "X30", "-", "CASE_END", "PASS", detailText
    RecordCaseResult _
        startedAt, "X30", "PASS", "built-in test vectors", _
        DiagnosticLogPath(), detailText
    ShowCaseResult _
        "X30", True, "built-in test vectors", _
        DiagnosticLogPath(), detailText
    Exit Sub

Failed:
    detailText = ErrorText(Err.Number, Err.Description)
    On Error Resume Next
    AppendDiagnosticStage _
        "X30", "-", "ERROR", "FAIL", detailText
    AppendDiagnosticStage _
        "X30", "-", "CASE_END", "FAIL", detailText
    RecordCaseResult _
        startedAt, "X30", "FAIL", "built-in test vectors", _
        DiagnosticLogPath(), detailText
    ShowCaseResult _
        "X30", False, "built-in test vectors", _
        DiagnosticLogPath(), detailText
    On Error GoTo 0
End Sub
