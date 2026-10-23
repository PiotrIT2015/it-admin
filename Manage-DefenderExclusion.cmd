@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-DefenderExclusion.ps1" %*

echo.
pause