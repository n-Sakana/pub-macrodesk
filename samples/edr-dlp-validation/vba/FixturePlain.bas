Attribute VB_Name = "FixturePlain"
Option Explicit

' Harmless fixture with no Win32 API declaration.
' It is never called by the validation cases.
Private Function PlainFixtureValue() As String
    PlainFixtureValue = "HARMLESS_PLAIN_FIXTURE"
End Function
