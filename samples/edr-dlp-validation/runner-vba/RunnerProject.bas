Attribute VB_Name = "RunnerProject"
Option Explicit

Private Const FIXTURE_COMPONENT_NAME As String = "FixtureModule"
Private Const IMPORTED_COMPONENT_NAME As String = "ImportedFixture"
Private Const STANDARD_MODULE_TYPE As Long = 1

Public Sub C1_ReadProjectFixture01()
    ExecuteProjectReadCase "C1", "01", True
End Sub

Public Sub C2_ReadProjectFixture02()
    ExecuteProjectReadCase "C2", "02", True
End Sub

Public Sub D1_WriteProjectFixture01()
    ExecuteProjectWriteCase "D1", "01", True
End Sub

Public Sub D2_WriteProjectFixture02()
    ExecuteProjectWriteCase "D2", "02", True
End Sub

Public Function ExecuteProjectReadCase( _
    ByVal caseId As String, _
    ByVal fixtureId As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim component As Object
    Dim detailText As String
    Dim fixtureBook As Workbook
    Dim inputPath As String
    Dim sourceText As String
    Dim startedAt As Date

    On Error GoTo Failed
    inputPath = FixtureBookPath(fixtureId)

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Open the selected fixture read-only with workbook events " & _
                "disabled, then read one named component through " & _
                "VBComponents and CodeModule.Lines.", _
            inputPath & " :: " & FIXTURE_COMPONENT_NAME, _
            "(read only)", _
            "The component source is read and its character count is " & _
                "reported. The fixture is closed without saving.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    Set fixtureBook = OpenBookReadOnlyForCase(inputPath)
    Set component = _
        fixtureBook.VBProject.VBComponents(FIXTURE_COMPONENT_NAME)
    sourceText = ReadComponentSource(component)
    fixtureBook.Close SaveChanges:=False
    Set fixtureBook = Nothing

    If Len(sourceText) = 0 Then
        Err.Raise vbObjectError + 2620, _
            "MacroStudioValidation", _
            "The selected component was empty."
    End If

    detailText = _
        "fixture=" & fixtureId & _
        "; characters=" & CStr(Len(sourceText)) & _
        "; read_only=true"
    RecordCaseResult _
        startedAt, caseId, "PASS", _
        inputPath & " :: " & FIXTURE_COMPONENT_NAME, _
        "(read only)", detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, _
            inputPath & " :: " & FIXTURE_COMPONENT_NAME, _
            "(read only)", detailText
    End If
    ExecuteProjectReadCase = True
    Exit Function

Failed:
    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ProjectAccessErrorText(Err.Number, Err.Description)
    On Error Resume Next
    If Not fixtureBook Is Nothing Then
        fixtureBook.Close SaveChanges:=False
    End If
    On Error GoTo 0

    RecordCaseResult _
        startedAt, caseId, "FAIL", _
        inputPath & " :: " & FIXTURE_COMPONENT_NAME, _
        "(read only)", detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, _
            inputPath & " :: " & FIXTURE_COMPONENT_NAME, _
            "(read only)", detailText
    End If
End Function

Public Function ExecuteProjectWriteCase( _
    ByVal caseId As String, _
    ByVal fixtureId As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim detailText As String
    Dim outputBook As Workbook
    Dim outputPath As String
    Dim persistedSource As String
    Dim sourcePath As String
    Dim sourceText As String
    Dim startedAt As Date
    Dim targetComponent As Object

    On Error GoTo Failed
    sourcePath = FixtureMirrorPath(fixtureId)
    outputPath = UniqueOutputPath( _
        caseId & "_fixture-" & fixtureId & "_project-copy", _
        ".xlsm")

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read the selected external source mirror, create a new " & _
                "workbook in output, add one standard component with " & _
                "CodeModule.AddFromString, save, reopen, and compare.", _
            sourcePath, _
            outputPath & " :: " & IMPORTED_COMPONENT_NAME, _
            "The persisted component matches the selected mirror. " & _
                "No source fixture or runner file is changed.") Then
            Exit Function
        End If
    End If

    startedAt = Now
    EnsureOutputFolder
    sourceText = SourceBodyFromExport(ReadTextFile(sourcePath))
    If Len(sourceText) = 0 Then
        Err.Raise vbObjectError + 2621, _
            "MacroStudioValidation", _
            "The selected source mirror was empty."
    End If

    Set outputBook = Application.Workbooks.Add(xlWBATWorksheet)
    outputBook.Worksheets(1).Name = "Output"
    outputBook.Worksheets(1).Range("A1").Value2 = _
        "Generated validation output"
    outputBook.SaveAs _
        Filename:=outputPath, _
        FileFormat:=xlOpenXMLWorkbookMacroEnabled, _
        CreateBackup:=False

    Set targetComponent = _
        outputBook.VBProject.VBComponents.Add(STANDARD_MODULE_TYPE)
    targetComponent.Name = IMPORTED_COMPONENT_NAME
    targetComponent.CodeModule.AddFromString sourceText
    outputBook.Save
    outputBook.Close SaveChanges:=False
    Set outputBook = Nothing

    Set outputBook = OpenBookReadOnlyForCase(outputPath)
    Set targetComponent = _
        outputBook.VBProject.VBComponents(IMPORTED_COMPONENT_NAME)
    persistedSource = ReadComponentSource(targetComponent)
    outputBook.Close SaveChanges:=False
    Set outputBook = Nothing

    If NormalizeSourceText(sourceText) <> _
        NormalizeSourceText(persistedSource) Then
        Err.Raise vbObjectError + 2622, _
            "MacroStudioValidation", _
            "The persisted component did not match the source mirror."
    End If

    detailText = _
        "fixture=" & fixtureId & _
        "; characters=" & CStr(Len(sourceText)) & _
        "; persisted_match=true"
    RecordCaseResult _
        startedAt, caseId, "PASS", sourcePath, _
        outputPath & " :: " & IMPORTED_COMPONENT_NAME, detailText
    If interactive Then
        ShowCaseResult _
            caseId, True, sourcePath, _
            outputPath & " :: " & IMPORTED_COMPONENT_NAME, _
            detailText
    End If
    ExecuteProjectWriteCase = True
    Exit Function

Failed:
    If startedAt = 0 Then
        startedAt = Now
    End If
    detailText = ProjectAccessErrorText(Err.Number, Err.Description)
    On Error Resume Next
    If Not outputBook Is Nothing Then
        outputBook.Close SaveChanges:=False
    End If
    On Error GoTo 0

    RecordCaseResult _
        startedAt, caseId, "FAIL", sourcePath, _
        outputPath & " :: " & IMPORTED_COMPONENT_NAME, detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, sourcePath, _
            outputPath & " :: " & IMPORTED_COMPONENT_NAME, _
            detailText
    End If
End Function

Private Function ProjectAccessErrorText( _
    ByVal errorNumber As Long, _
    ByVal errorDescription As String) As String

    ProjectAccessErrorText = _
        ErrorText(errorNumber, errorDescription) & vbCrLf & _
        "Only C1, C2, D1, and D2 require Excel's ""Trust access " & _
        "to the VBA project object model"" setting."
End Function
