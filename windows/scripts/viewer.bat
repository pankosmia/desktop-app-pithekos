@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\viewer.bat
REM .\build_viewer.ps1 must be run once before .\viewer.bat will work

set "ROCKET_PORT=%~1"
if "%ROCKET_PORT%"=="" set "ROCKET_PORT=19119"

echo ========================
echo(
echo Starting electronite viewer, accessing the development build environment running at port shown below:

REM Using devevelopment server.

REM Starting electronite viewer, accessing the development build environment

REM This bypasses viewer\appLauncherElectron.bat
..\viewer\project\payload\app\electron\electron.exe ..\viewer\project\payload\app\electron
