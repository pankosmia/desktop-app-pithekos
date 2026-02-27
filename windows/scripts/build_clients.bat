@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in PowerShell or cmd by:  .\build_clients.bat

REM The -d positional argument means to delete past logs without asking
set "deleteLogs="

:loop
if "%~1"=="" goto :continue
if /I "%~1"=="-d" set "deleteLogs=-d"
shift
goto :loop

:continue

REM Assign default value if -d is not present
if not defined deleteLogs set "deleteLogs=-no"

if exist "build_clients_*.log" (
  echo.
  :choice
  if /I "%deleteLogs%"=="-d" (
    goto :delete_logs
  ) else (
    set /P "c=Delete past logs? [Y/n]: "
  )
  if /I "%c%"==""  goto :delete_logs
  if /I "%c%"=="Y" goto :delete_logs
  if /I "%c%"=="N" goto :moving_on
  echo "%c%" is not a valid response. Type y or 'Enter' to delete past logs or 'n' to keep them.
  goto :choice

  :delete_logs
  del /q "build_clients_*.log"
)

:moving_on

for /F "tokens=1,2 delims==" %%A in (..\..\app_config.env) do set %%A=%%B

setlocal ENABLEDELAYEDEXPANSION

REM ---- logging + failure tracking ----
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
set "LOG=%~dp0build_clients_%TS%.log"
> "%LOG%" echo ===== Build started %DATE% %TIME% =====
set /a FAILCOUNT=0

REM Create a tiny PowerShell helper script once (used for tee-ing output)
set "PSRUNNER=%TEMP%\bat_tee_run.ps1"
del "%PSRUNNER%" 2>nul
>  "%PSRUNNER%" echo $LogPath = $args[0]
>> "%PSRUNNER%" echo $cmdLine = ($args ^| Select-Object -Skip 1^) -join ' '
>> "%PSRUNNER%" echo $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
>> "%PSRUNNER%" echo $sw = New-Object System.IO.StreamWriter($LogPath,$true,$utf8NoBom)
>> "%PSRUNNER%" echo try {
>> "%PSRUNNER%" echo   cmd.exe /d /s /c ^"$cmdLine 2^>^&1^" ^| ForEach-Object {
>> "%PSRUNNER%" echo     $_
>> "%PSRUNNER%" echo     $clean = [regex]::Replace($_, '\x1B\[[0-?]*[ -/]*[@-~]', '')
>> "%PSRUNNER%" echo     $sw.WriteLine($clean)
>> "%PSRUNNER%" echo   }
>> "%PSRUNNER%" echo } finally { $sw.Dispose() }
>> "%PSRUNNER%" echo exit $LASTEXITCODE
REM -----------------------------------

set count=0
for /f "tokens=*" %%a in (..\..\app_config.env) do (
  set /a count+=1
)

cd ..\..\
for %%I in (.) do set "RepoDirName=%%~nxI"
cd ..\

for /l %%a in (1,1,%count%) do (
  if "!ASSET%%a!" NEQ "" (
    REM Remove any spaces, e.g. trailing ones
    set "ASSET%%a=!ASSET%%a: =!"
    call :log ############################### BEGIN Asset %%a: !ASSET%%a! ###############################
    if not exist !ASSET%%a! (
      call :log
      call :log ****************************************************
      call :log !ASSET%%a! does not exist; Run .\clone.bat
      call :log ****************************************************
      call :log
    ) else (
      cd !ASSET%%a!
      call :log ^> git checkout main...
      call :run git checkout main
      if errorlevel 1 call :markfail "ASSET" "!ASSET%%a!" "git checkout main"

      call :log ^> git pull...
      call :run git pull
      if errorlevel 1 call :markfail "ASSET" "!ASSET%%a!" "git pull"

      call :log ################################ END Asset %%a: !ASSET%%a! ################################
      call :log
      cd ..
    )
  )
)

for /l %%a in (1,1,%count%) do (
  if "!CLIENT%%a!" NEQ "" (
    REM Remove any spaces, e.g. trailing ones
    set "CLIENT%%a=!CLIENT%%a: =!"
    call :log ############################### BEGIN Client %%a: !CLIENT%%a! ###############################
    if not exist !CLIENT%%a! (
      call :log
      call :log ***************************************************************************************
      call :log !CLIENT%%a! does not exist; Run .\clone.bat then rerun .\build_clients_main.bat
      call :log ***************************************************************************************
      call :log
    ) else (
      cd !CLIENT%%a!
      call :log ^> git checkout main...
      call :run git checkout main
      if errorlevel 1 call :markfail "CLIENT" "!CLIENT%%a!" "git checkout main"

      call :log ^> git pull...
      call :run git pull
      if errorlevel 1 call :markfail "CLIENT" "!CLIENT%%a!" "git pull"

      call :log ^> npm ci...
      call :run npm ci
      if errorlevel 1 call :markfail "CLIENT" "!CLIENT%%a!" "npm ci"

      call :log ^> npm run build...
      call :run npm run build
      if errorlevel 1 call :markfail "CLIENT" "!CLIENT%%a!" "npm run build"

      call :log ################################ END Client %%a: !CLIENT%%a! ################################
      call :log
      cd ..
    )
  )
)

cd %RepoDirName%\windows\scripts

REM ---- concise summary ----
echo.
echo ================================= SUMMARY =================================
if %FAILCOUNT% EQU 0 (
  echo All builds succeeded.
) else (
  echo Failed steps: %FAILCOUNT%
  for /l %%i in (1,1,%FAILCOUNT%) do echo !FAIL%%i!
)
echo.
if /i "%GITHUB_ACTIONS%"=="true" (
  echo Full log: scroll up in the "Run build_clients.bat" step output above.
) else (
  for %%F in ("%LOG%") do echo Full log: "%%~nxF" in the current directory.
)
echo ===========================================================================

set "EXITCODE=0"
if %FAILCOUNT% GTR 0 set "EXITCODE=1"

endlocal
exit /b %EXITCODE%


:log
REM Echo to screen AND append the same line to %LOG% (UTF-8, no BOM)
set "LINE=%*"
if "%~1"=="" (
  echo.
  powershell -NoProfile -Command "[System.IO.File]::AppendAllText($env:LOG, [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))" >nul
) else (
  echo %LINE%
  powershell -NoProfile -Command "$s=$env:LINE; [System.IO.File]::AppendAllText($env:LOG, $s + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))" >nul
)
exit /b 0


:run
REM Runs a command, shows output live, and appends the same output to %LOG%.
REM Preserves the original program exit code.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSRUNNER%" "%LOG%" %*
exit /b %errorlevel%


:markfail
set /a FAILCOUNT+=1
set "FAIL!FAILCOUNT!=[%~1] %~2 :: %~3"
exit /b 0
