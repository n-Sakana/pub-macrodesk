Attribute VB_Name = "FixtureModule"
Option Explicit

#If VBA7 Then
Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal milliseconds As LongPtr)
#Else
Private Declare Sub Sleep Lib "kernel32" (ByVal milliseconds As Long)
#End If
