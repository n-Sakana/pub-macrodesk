@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0macrostudio.ps1"
set "MACROSTUDIO_EXIT=%ERRORLEVEL%"
rem Keep the console open so a startup error stays readable.
if not "%MACROSTUDIO_EXIT%"=="0" pause
exit /b %MACROSTUDIO_EXIT%
