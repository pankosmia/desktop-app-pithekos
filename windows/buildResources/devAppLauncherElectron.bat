@echo off

REM This is an alternative production launcher for developer use. It shows Electron stdio in the terminal.

REM Location: same directory as bin\, lib\ and electron\

setlocal

echo.
echo ==================================================================
echo Starting up with Electron stdin, stdout and stderr in the console:
echo.

REM Run everything from the directory this script is in
cd /d "%~dp0"
echo Running everything from: %cd%
echo.

set "APP_RESOURCES_DIR=.\lib\"
echo APP_RESOURCES_DIR=%APP_RESOURCES_DIR%
echo.

echo Starting with: .\electron\electron.exe .\electron
echo.
.\electron\electron.exe .\electron

endlocal
