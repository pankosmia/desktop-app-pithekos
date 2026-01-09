@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\viewer.bat
REM .\build_viewer.ps1 must be run once before .\viewer.bat will work

set "ROCKET_PORT=%~1"
if "%ROCKET_PORT%"=="" set "ROCKET_PORT=19119"

echo ========================
echo
echo Starting electronite viewer...

REM Using dev server.

REM Starting electronite viewer loading dev build environment
set "APP_RESOURCES_DIR=..\..\build\lib\"

REM This bypasses viewer\appLauncherElectron.bat
..\viewer\project\payload\app\electron\electron.exe ..\viewer\project\payload\app\electron &
