@echo off
setlocal

echo.
echo ==================================================================
echo Starting up with Electron stdin, stdout and stderr in the console:
echo.
echo Current directory: %cd%
echo.

REM Find server.exe

REM First look for server.exe relative to directory script is in
if exist "%SCRIPT_DIR%\..\bin\server.exe" (
    set "BASE=%SCRIPT_DIR%\.."
) else if exist ".\bin\server.exe" (
    set "BASE=."
) else if exist "..\bin\server.exe" (
    set "BASE=.."
) else (
    echo Error: server.exe not found in expected locations
    exit /b 1
)

echo bin folder found at %BASE%
echo.

REM Start electron as background process
echo cd /d "%BASE%"
cd /d "%BASE%"
echo.

set "APP_RESOURCES_DIR=.\lib\"
echo APP_RESOURCES_DIR=%APP_RESOURCES_DIR%
echo.

echo Starting with: .\electron\electron.exe .\electron
.\electron\electron.exe .\electron

endlocal