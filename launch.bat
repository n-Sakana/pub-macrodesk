@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0macrodesk.ps1"
set "MACRODESK_EXIT=%ERRORLEVEL%"
rem Keep the console open so a startup error stays readable.
if not "%MACRODESK_EXIT%"=="0" pause
exit /b %MACRODESK_EXIT%
