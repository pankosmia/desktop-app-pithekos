@echo off

REM This is an alternative production launcher for developer use. It shows Electron stdio in the terminal.

REM Location: same directory as bin\, lib\ and electron\

REM Works in both production layouts:
REM   Installed: <InstallDir>\devAppLauncherElectron.bat
REM   Portable:  <portableRoot>\<App Name>\devAppLauncherElectron.bat
REM The working directory is set to the parent folder as portable AppData resolves relative to it.

setlocal

echo.
echo ==================================================================
echo Starting up with Electron stdin, stdout and stderr in the console:
echo.

REM Absolute directory of this script (has a trailing backslash)
set "BASE_DIR=%~dp0"

REM Run from the parent directory (the portable root in the portable layout)
cd /d "%BASE_DIR%.."
echo Running everything from: %cd%
echo.

set "APP_RESOURCES_DIR=.\lib\"
echo APP_RESOURCES_DIR=%APP_RESOURCES_DIR%
echo.

echo Starting with: "%BASE_DIR%electron\electron.exe" "%BASE_DIR%electron"
echo.
"%BASE_DIR%electron\electron.exe" "%BASE_DIR%electron"

endlocal
