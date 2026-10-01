@echo off
setlocal
title ROG P711 patchB installer

if "%~1"=="" goto online

set "FW_DIR=%~1"
echo Offline mode: using the supplied ASUS Firmware folder.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-patchB.ps1" -FirmwareDirectory "%FW_DIR%" -Install
goto finished

:online
echo Online mode: downloading the verified updater package from ASUS.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0download-and-install.ps1"

:finished
set "RESULT=%ERRORLEVEL%"

echo.
if not "%RESULT%"=="0" echo patchB did not complete. Review the error above.
pause
exit /b %RESULT%
