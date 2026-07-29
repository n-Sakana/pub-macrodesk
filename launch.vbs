' This file must stay pure ASCII. wscript.exe reads a .vbs as the system ANSI
' code page unless it starts with a UTF-16 byte order mark, so a non-ASCII
' character saved as UTF-8 makes the whole script fail to compile. Japanese
' wording therefore lives in README.md and in the log file, not here.

Option Explicit

Dim shell
Dim fileSystem
Dim baseDir
Dim scriptPath
Dim command
Dim exitCode
Dim logDir

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

baseDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fileSystem.BuildPath(baseDir, "macrostudio.ps1")
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " _
    & Chr(34) & scriptPath & Chr(34)

shell.CurrentDirectory = baseDir

' The launcher window stays hidden, but this waits for it so that a startup
' failure can still be reported instead of disappearing without a trace.
exitCode = shell.Run(command, 0, True)

' macrostudio.ps1 returns 3 only when it fails before the window opens. Any other
' code, including a forced shutdown of a running MacroStudio, is left alone.
If exitCode = 3 Then
    logDir = fileSystem.BuildPath( _
        shell.ExpandEnvironmentStrings("%LOCALAPPDATA%"), "MacroStudio\logs")
    MsgBox _
        "MacroStudio could not start." & vbCrLf & vbCrLf & _
        "The reason was written to the newest log file in:" & vbCrLf & _
        logDir & vbCrLf & vbCrLf & _
        "If this folder came from a zip download, follow " & _
        """Mark of the Web"" in README.md.", _
        vbExclamation, "MacroStudio"
End If
