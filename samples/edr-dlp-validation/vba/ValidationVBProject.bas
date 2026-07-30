Attribute VB_Name = "ValidationVBProject"
Option Explicit

Private Const STANDARD_MODULE_TYPE As Long = 1

Public Sub B1_VBProject_Read_Plain()
    ExecuteProjectReadCase _
        "B1", _
        "FixturePlain", _
        "plain harmless VBA component", _
        True
End Sub

Public Sub B2_VBProject_Read_PtrSafeText()
    ExecuteProjectReadCase _
        "B2", _
        "FixturePtrSafe", _
        "component containing a static PtrSafe Sleep declaration", _
        True
End Sub

Public Sub B3_VBProject_WriteCopy_Plain()
    ExecuteProjectWriteCase _
        "B3", _
        "FixturePlain", _
        "EDRPlainCopy", _
        "B3_vbproject_plain_copy", _
        "plain harmless VBA component", _
        True
End Sub

Public Sub B4_VBProject_WriteCopy_PtrSafeText()
    ExecuteProjectWriteCase _
        "B4", _
        "FixturePtrSafe", _
        "EDRPtrSafeCopy", _
        "B4_vbproject_ptrsafe_copy", _
        "component containing a static PtrSafe Sleep declaration", _
        True
End Sub

Public Function ExecuteProjectReadCase( _
    ByVal caseId As String, _
    ByVal componentName As String, _
    ByVal fixtureDescription As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim component As Object
    Dim detailText As String
    Dim sourceText As String
    Dim startedAt As Date

    On Error GoTo Failed
    startedAt = Now

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Read one named component through " & _
                "VBProject.VBComponents and CodeModule.Lines.", _
            ThisWorkbook.FullName & " :: " & componentName, _
            "No file and no VBA component is written.", _
            "The component source is read and its character count and " & _
                "visible preview are reported.") Then
            Exit Function
        End If
    End If

    Set component = ThisWorkbook.VBProject.VBComponents(componentName)
    sourceText = ReadComponentSource(component)
    detailText = "Fixture: " & fixtureDescription & vbCrLf & _
        "Characters read: " & CStr(Len(sourceText)) & vbCrLf & _
        "Preview:" & vbCrLf & PreviewText(sourceText, 700)

    RecordCaseResult _
        startedAt, caseId, "PASS", _
        ThisWorkbook.FullName & " :: " & componentName, _
        "(read only)", _
        "characters=" & CStr(Len(sourceText))
    If interactive Then
        ShowCaseResult _
            caseId, True, _
            ThisWorkbook.FullName & " :: " & componentName, _
            "(read only)", _
            detailText
    End If
    ExecuteProjectReadCase = True
    Exit Function

Failed:
    detailText = ProjectAccessErrorText(Err.Number, Err.Description)
    RecordCaseResult _
        startedAt, caseId, "FAIL", _
        ThisWorkbook.FullName & " :: " & componentName, _
        "(read only)", _
        detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, _
            ThisWorkbook.FullName & " :: " & componentName, _
            "(read only)", _
            detailText
    End If
End Function

Public Function ExecuteProjectWriteCase( _
    ByVal caseId As String, _
    ByVal sourceComponentName As String, _
    ByVal destinationComponentName As String, _
    ByVal outputPrefix As String, _
    ByVal fixtureDescription As String, _
    Optional ByVal interactive As Boolean = True) As Boolean

    Dim copyBook As Workbook
    Dim detailText As String
    Dim failureDescription As String
    Dim failureNumber As Long
    Dim outputPath As String
    Dim persistedSource As String
    Dim sourceComponent As Object
    Dim sourceText As String
    Dim startedAt As Date
    Dim targetComponent As Object

    On Error GoTo Failed
    startedAt = Now
    outputPath = UniqueOutputPath(outputPrefix, ".xlsm")

    If interactive Then
        If Not ConfirmCase( _
            caseId, _
            "Create a new workbook copy, open that copy, add one " & _
                "standard VBA component with CodeModule.AddFromString, " & _
                "save and reopen the copy, then compare the persisted " & _
                "source. The original workbook is not saved.", _
            ThisWorkbook.FullName & " :: " & sourceComponentName, _
            outputPath & " :: " & destinationComponentName, _
            "The new component in the new workbook copy matches the " & _
                "source exactly. No API declared by the fixture is called.") Then
            Exit Function
        End If
    End If

    EnsureOutputFolder
    Set sourceComponent = _
        ThisWorkbook.VBProject.VBComponents(sourceComponentName)
    sourceText = ReadComponentSource(sourceComponent)
    If Len(sourceText) = 0 Then
        Err.Raise vbObjectError + 2420, _
            "MacroStudioValidation", _
            "The source component was empty."
    End If

    ThisWorkbook.SaveCopyAs outputPath
    Set copyBook = Application.Workbooks.Open( _
        Filename:=outputPath, _
        UpdateLinks:=0, _
        ReadOnly:=False, _
        AddToMru:=False)

    Set targetComponent = _
        copyBook.VBProject.VBComponents.Add(STANDARD_MODULE_TYPE)
    targetComponent.Name = destinationComponentName
    targetComponent.CodeModule.AddFromString sourceText
    copyBook.Save
    copyBook.Close SaveChanges:=False
    Set copyBook = Nothing

    Set copyBook = Application.Workbooks.Open( _
        Filename:=outputPath, _
        UpdateLinks:=0, _
        ReadOnly:=True, _
        AddToMru:=False)
    Set targetComponent = _
        copyBook.VBProject.VBComponents(destinationComponentName)
    persistedSource = ReadComponentSource(targetComponent)

    If NormalizeSourceText(sourceText) <> _
        NormalizeSourceText(persistedSource) Then
        Err.Raise vbObjectError + 2421, _
            "MacroStudioValidation", _
            "The persisted source did not match the source component."
    End If

    copyBook.Close SaveChanges:=False
    Set copyBook = Nothing

    detailText = "Fixture: " & fixtureDescription & vbCrLf & _
        "Characters written: " & CStr(Len(sourceText)) & vbCrLf & _
        "Verification after reopen: exact normalized source match" & _
        vbCrLf & _
        "The original workbook was not saved or changed on disk."
    RecordCaseResult _
        startedAt, caseId, "PASS", _
        ThisWorkbook.FullName & " :: " & sourceComponentName, _
        outputPath & " :: " & destinationComponentName, _
        "characters=" & CStr(Len(sourceText)) & _
            "; persisted_match=true"
    If interactive Then
        ShowCaseResult _
            caseId, True, _
            ThisWorkbook.FullName & " :: " & sourceComponentName, _
            outputPath & " :: " & destinationComponentName, _
            detailText
    End If
    ExecuteProjectWriteCase = True
    Exit Function

Failed:
    failureNumber = Err.Number
    failureDescription = Err.Description
    detailText = ProjectAccessErrorText( _
        failureNumber, failureDescription)
    On Error Resume Next
    If Not copyBook Is Nothing Then
        copyBook.Close SaveChanges:=False
    End If
    On Error GoTo 0

    RecordCaseResult _
        startedAt, caseId, "FAIL", _
        ThisWorkbook.FullName & " :: " & sourceComponentName, _
        outputPath & " :: " & destinationComponentName, _
        detailText
    If interactive Then
        ShowCaseResult _
            caseId, False, _
            ThisWorkbook.FullName & " :: " & sourceComponentName, _
            outputPath & " :: " & destinationComponentName, _
            detailText
    End If
End Function

Private Function ProjectAccessErrorText( _
    ByVal errorNumber As Long, _
    ByVal errorDescription As String) As String

    ProjectAccessErrorText = _
        "Error " & CStr(errorNumber) & ": " & errorDescription & _
        vbCrLf & vbCrLf & _
        "Only B1-B4 require Excel's ""Trust access to the VBA " & _
        "project object model"" setting. No other case requires it."
End Function
