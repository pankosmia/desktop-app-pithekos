@echo off
setlocal enabledelayedexpansion

echo ========================
echo Starting up:
echo Current directory:
cd

REM Get the directory path that contains this script
set "SCRIPT_DIR=%~dp0"
echo Script directory: %SCRIPT_DIR%

REM Need to find server.exe - this is needed because working directory is not set

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

REM set available port environment variable (returned as %ROCKET_PORT% )
call .\find_free_port.bat

REM Start electron as background process
cd /d "%BASE%"
set "APP_RESOURCES_DIR=.\lib\"
.\electron\electron.exe .\electron &

endlocal