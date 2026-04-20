@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in PowerShell or cmd by:  .\build_clients.bat

REM Usage:
REM   .\build_clients.bat [branch] [fallback_tier] [-d] [-f]
REM     The -d argument means to delete past logs without asking
REM     The -f argument means only fresh clones are being built, so pulling is skipped.
REM     The first non-flag argument is the branch name (default: main)
REM     The second non-flag argument is the fallback tier: dev, qa, or main (default: same as branch)

REM Examples:
REM   .\build_clients.bat                        # defaults to "main"
REM   .\build_clients.bat dev                    # tries dev → qa → main
REM   .\build_clients.bat my-branch dev          # tries my-branch → dev → qa → main
REM   .\build_clients.bat my-branch qa -d        # tries my-branch → qa → main, deletes past logs
REM   .\build_clients.bat -f -d dev              # fresh clones (skips pulling), delete logs, branch=dev → qa → main

set "SCRIPT_DIR=%~dp0"
set "deleteLogs="
set "BRANCH="
set "FALLBACK_TIER="
set "FRESH_CLONE="

:loop
if "%~1"=="" goto :continue
if /I "%~1"=="-d" (
  set "deleteLogs=-d"
  shift
  goto :loop
)
if /I "%~1"=="-f" (
  set "FRESH_CLONE=1"
  shift
  goto :loop
)
REM First non-flag argument is the branch
if not defined BRANCH (
  set "BRANCH=%~1"
  shift
  goto :loop
)
REM Second non-flag argument is the fallback tier
if not defined FALLBACK_TIER (
  set "FALLBACK_TIER=%~1"
  shift
  goto :loop
)
shift
goto :loop

:continue

REM Assign default values
if not defined deleteLogs set "deleteLogs=-no"
if not defined BRANCH set "BRANCH=main"

REM If no fallback tier specified, derive from the branch itself
if not defined FALLBACK_TIER (
  if /I "%BRANCH%"=="dev" (
    set "FALLBACK_TIER=dev"
  ) else if /I "%BRANCH%"=="qa" (
    set "FALLBACK_TIER=qa"
  ) else (
    set "FALLBACK_TIER=main"
  )
)

REM Normalize fallback tier: anything other than dev or qa becomes main
if /I "%FALLBACK_TIER%"=="dev" (
  set "FALLBACK_TIER=dev"
) else if /I "%FALLBACK_TIER%"=="qa" (
  set "FALLBACK_TIER=qa"
) else (
  set "FALLBACK_TIER=main"
)

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
set "LOG=%SCRIPT_DIR%build_clients_%TS%.log"
> "%LOG%" echo ===== Build started %DATE% %TIME% =====
set /a FAILCOUNT=0
set /a SKIPCOUNT=0

REM Create a PowerShell helper script (used for tee-ing output)
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
      call :checkout_branch "ASSET" "!ASSET%%a!"
      call :safe_pull "ASSET" "!ASSET%%a!"

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
      call :checkout_branch "CLIENT" "!CLIENT%%a!"
      call :safe_pull "CLIENT" "!CLIENT%%a!"

      call :log -- npm ci...
      call :run npm ci
      if errorlevel 1 call :markfail "CLIENT" "!CLIENT%%a!" "npm ci"

      call :log -- npm run build...
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
  for /l %%i in (1,1,%FAILCOUNT%) do echo   !FAIL%%i!
)
if %SKIPCOUNT% GTR 0 (
  echo.
  echo Skipped pulls: %SKIPCOUNT%
  for /l %%i in (1,1,%SKIPCOUNT%) do echo   !SKIP%%i!
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


:checkout_branch
REM %~1 = type (ASSET or CLIENT), %~2 = repo name
REM Uses %BRANCH% and %FALLBACK_TIER% to determine checkout with fallback.
REM Sets CHECKED_OUT_BRANCH to the branch that was actually checked out.
set "CB_TYPE=%~1"
set "CB_REPO=%~2"

call :log -- git checkout %BRANCH%...
call :run git checkout "%BRANCH%"
if not errorlevel 1 (
  set "CHECKED_OUT_BRANCH=%BRANCH%"
  goto :checkout_done
)

REM Branch didn't exist -- apply fallback based on FALLBACK_TIER
if /I "%FALLBACK_TIER%"=="dev" (
  REM Fallback chain: dev -> qa -> main
  if /I "%BRANCH%" NEQ "dev" (
    call :log -- Branch "%BRANCH%" not found, trying "dev"...
    call :run git checkout dev
    if not errorlevel 1 (
      set "CHECKED_OUT_BRANCH=dev"
      goto :checkout_done
    )
  )

  call :log -- Branch "dev" not found, trying "qa"...
  call :run git checkout qa
  if not errorlevel 1 (
    set "CHECKED_OUT_BRANCH=qa"
    goto :checkout_done
  )

  call :log -- Branch "qa" not found, falling back to "main"...
  call :run git checkout main
  if errorlevel 1 (
    call :markfail "%CB_TYPE%" "%CB_REPO%" "git checkout main (fallback from %BRANCH%)"
  )
  set "CHECKED_OUT_BRANCH=main"
  goto :checkout_done
)

if /I "%FALLBACK_TIER%"=="qa" (
  REM Fallback chain: qa -> main
  if /I "%BRANCH%" NEQ "qa" (
    call :log -- Branch "%BRANCH%" not found, trying "qa"...
    call :run git checkout qa
    if not errorlevel 1 (
      set "CHECKED_OUT_BRANCH=qa"
      goto :checkout_done
    )
  )

  call :log -- Branch "qa" not found, falling back to "main"...
  call :run git checkout main
  if errorlevel 1 (
    call :markfail "%CB_TYPE%" "%CB_REPO%" "git checkout main (fallback from %BRANCH%)"
  )
  set "CHECKED_OUT_BRANCH=main"
  goto :checkout_done
)

REM FALLBACK_TIER is main -- fall back directly to main
call :log -- Branch "%BRANCH%" not found, falling back to "main"...
call :run git checkout main
if errorlevel 1 (
  call :markfail "%CB_TYPE%" "%CB_REPO%" "git checkout main (fallback from %BRANCH%)"
)
set "CHECKED_OUT_BRANCH=main"

:checkout_done
exit /b 0


:safe_pull
REM %~1 = type (ASSET or CLIENT), %~2 = repo name
set "SP_TYPE=%~1"
set "SP_REPO=%~2"

if defined FRESH_CLONE (
  call :log -- Skipping pull -- -f flag set, 'fresh' clone, no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "-f flag set, 'fresh' clone, no pull"
  goto :safe_pull_done
)

git diff --quiet >nul 2>&1
set "DIRTY1=!errorlevel!"
git diff --cached --quiet >nul 2>&1
set "DIRTY2=!errorlevel!"
if !DIRTY1! NEQ 0 (
  call :log -- Skipping pull -- uncommitted local changes detected on "!CHECKED_OUT_BRANCH!", no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "uncommitted local changes, no pull"
  goto :safe_pull_done
)
if !DIRTY2! NEQ 0 (
  call :log -- Skipping pull -- uncommitted local changes detected on "!CHECKED_OUT_BRANCH!", no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "uncommitted local changes, no pull"
  goto :safe_pull_done
)

git rev-parse --verify "origin/!CHECKED_OUT_BRANCH!" >nul 2>&1
if errorlevel 1 (
  call :log -- Skipping pull -- origin/!CHECKED_OUT_BRANCH! does not exist, no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "origin/!CHECKED_OUT_BRANCH! does not exist, no pull"
  goto :safe_pull_done
)

for /f %%n in ('git rev-list "origin/!CHECKED_OUT_BRANCH!..HEAD" --count 2^>nul') do set "LOCAL_AHEAD=%%n"
if !LOCAL_AHEAD! GTR 0 (
  call :log -- Skipping pull -- "!CHECKED_OUT_BRANCH!" has !LOCAL_AHEAD! unpushed commits, no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "!LOCAL_AHEAD! unpushed commits, no pull"
  goto :safe_pull_done
)

call :log -- git pull origin !CHECKED_OUT_BRANCH!...
call :run git pull origin "!CHECKED_OUT_BRANCH!"
if errorlevel 1 call :markfail "%SP_TYPE%" "%SP_REPO%" "git pull origin !CHECKED_OUT_BRANCH!"

:safe_pull_done
exit /b 0


:log
REM Echo to screen AND append the same line to %LOG% (UTF-8, no BOM)
set "LINE=%*"
if "%~1"=="" (
  echo.
  powershell -NoProfile -Command "[System.IO.File]::AppendAllText($env:LOG, [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))" >nul
) else (
  echo !LINE!
  powershell -NoProfile -Command "$s=$env:LINE; [System.IO.File]::AppendAllText($env:LOG, $s + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))" >nul
)
exit /b 0


:run
REM Runs a command, shows output live, and appends the same output to %LOG%.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSRUNNER%" "%LOG%" %*
exit /b %errorlevel%


:markfail
set /a FAILCOUNT+=1
set "FAIL!FAILCOUNT!=[%~1] %~2 :: %~3"
exit /b 0


:markskip
set /a SKIPCOUNT+=1
set "SKIP!SKIPCOUNT!=[%~1] %~2 (%~3): %~4"
exit /b 0
