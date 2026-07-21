@echo off
REM This file is used by GHA to send a version suffix argument.
REM The argument will be appended to the end of APP_VERSION in app_config.env

IF "%~1"=="" (
  goto :continue
) ELSE (
  set "suffix=%~1"
)

REM Rewrite the APP_VERSION in app_config.env
set "configFile=..\..\app_config.env"

setlocal enabledelayedexpansion
echo.
echo   Using version suffix "%suffix%"

set "configTmp=..\..\app_config.env.tmp"
(for /f "usebackq tokens=*" %%a in ("!configFile!") do (
  set "line=%%a"
  echo !line! | findstr /C:"APP_VERSION" >nul
  if !errorlevel! equ 0 (
    echo !line!-%suffix%
  ) else (
    echo(!line!
  )
)) > "!configTmp!"
move /y "!configTmp!" "!configFile!" >nul
endlocal

:continue