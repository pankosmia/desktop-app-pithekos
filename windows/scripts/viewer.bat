@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\viewer.bat
REM .\build_viewer.ps1 must be run once before .\viewer.bat will work

set "ROCKET_PORT=%~1"
if "%ROCKET_PORT%"=="" set "ROCKET_PORT=19119"

echo Starting the Electronite viewer.
echo Accessing the backend server at port %ROCKET_PORT%.

REM Using development environment server.
set START_SERVER=false

REM Starting electronite viewer, accessing the development build environment
..\viewer\project\payload\app\electron\electron.exe ..\viewer\project\payload\app\electron
