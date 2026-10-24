@echo off
setlocal

REM ============================================================
REM Microsoft Defender Exclusion Manager
REM Launcher for Manage-DefenderExclusion.ps1
REM ============================================================

set "SCRIPT=%~dp0Manage-DefenderExclusion.ps1"

REM Check whether the PowerShell script exists
if not exist "%SCRIPT%" (
    echo ERROR: PowerShell script not found:
    echo "%SCRIPT%"
    echo.
    pause
    exit /b 1
)

REM No arguments: start interactive menu
if "%~1"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode Menu
) else (
    REM Pass the mode and optional path to PowerShell
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode "%~1" -Path "%~2"
)

echo.
pause
endlocal