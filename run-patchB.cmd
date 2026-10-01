@echo off
setlocal
title ROG P711 patchB installer

if "%~1"=="" (
    echo Enter the full path to the official Firmware folder.
    echo You can also drag the Firmware folder onto this CMD file.
    set /p "FW_DIR=Firmware folder: "
) else (
    set "FW_DIR=%~1"
)

if not defined FW_DIR (
    echo No folder was provided.
    pause
    exit /b 2
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-patchB.ps1" -FirmwareDirectory "%FW_DIR%" -Install
set "RESULT=%ERRORLEVEL%"

echo.
if not "%RESULT%"=="0" echo patchB did not complete. Review the error above.
pause
exit /b %RESULT%
