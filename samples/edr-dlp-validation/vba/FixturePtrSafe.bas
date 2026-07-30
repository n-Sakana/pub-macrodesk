Attribute VB_Name = "FixturePtrSafe"
Option Explicit

' Static declaration fixture only. Sleep is never called.
#If VBA7 Then
Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal milliseconds As LongPtr)
#Else
Private Declare Sub Sleep Lib "kernel32" (ByVal milliseconds As Long)
#End If

Private Function PtrSafeFixtureDescription() As String
    PtrSafeFixtureDescription = "STATIC_DECLARATION_ONLY_NOT_EXECUTED"
End Function
