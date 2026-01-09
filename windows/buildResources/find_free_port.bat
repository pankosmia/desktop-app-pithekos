REM This script finds the first available port starting with default continuing up until the max port
REM It is returned as the environment variable ROCKET_PORT
REM Use `call` to run the file from another batch script

@echo off
setlocal enabledelayedexpansion

REM Find first free TCP port starting at %PORT% (default 19119)
set "PORT=%~1"
if "%PORT%"=="" set "PORT=19119"
set "MAX_PORT=65535"

where netstat >nul 2>&1
if errorlevel 1 (
  echo "Netstat is not available."
  echo "Will use the default port and hope it is not already in use."
  endlocal & set "ROCKET_PORT=%PORT%"
  goto :EOF
)

:scan_loop
if !PORT! GTR %MAX_PORT% (
  endlocal
  echo No free TCP port found up to %MAX_PORT% 1>&2
  exit /b 1
)

set "LISTENING=0"
for /f "usebackq delims=" %%L in (`netstat -ano -p tcp 2^>nul`) do (
  set "line=%%L"
  echo "!line!" | findstr /C:":!PORT! " /C:":!PORT!" >nul
  if not errorlevel 1 (
    echo "!line!" | findstr /I "LISTENING" >nul
    if errorlevel 1 (
      echo "!line!" | findstr /I "\<LISTEN\>" >nul
    )
    if not errorlevel 1 (
      set "LISTENING=1"
      goto :after_for
    )
  )
)
:after_for
if "!LISTENING!"=="1" (
  set /a PORT+=1
  goto :scan_loop
)

REM candidate found: move chosen port into outer env
endlocal & set "ROCKET_PORT=%PORT%"
