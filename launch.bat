@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0macrodesk.ps1"
exit /b %ERRORLEVEL%
