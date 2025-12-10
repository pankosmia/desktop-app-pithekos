@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\run.bat
REM Optional argument: `.\run.bat -s` to pre-confirm the server is off, so as to not be asked.
REM Optional argument: `.\run.bat -d` to run the server in debug mode.

REM Do not ask if the server is off if the -s positional argument is provided in either #1 or #2
REM Debug server if the -d positional argument is provided in either #1 or #2
:loop
IF "%~1"=="" (
  goto :continue
) ELSE IF "%~1"=="-s" (
  set askIfOff=%~1
) ELSE IF "%~1"=="-d" (
  set debugServer=%~1
)
shift
goto :loop

:continue

REM Assign default value if -s is not present
if not defined %askIfOff (
  set askIfOff=-yes
)

REM Assign default value if -d is not present
if not defined %debugServer (
  set debugServer=-no
  set "search=local_server/target/debug"
  set "replace=local_server/target/release"
  set "serverType=release"
  if not exist ..\..\local_server\target\release\local_server.exe (
    set "script=.\build_server.bat"
    goto :missing_server
  ) else (
    goto :server_build_exists
  )
) else if "%debugServer%"=="-d" (
  set "search=local_server/target/release"
  set "replace=local_server/target/debug"
  set "serverType=debug"
  if not exist ..\..\local_server\target\debug\local_server.exe (
    set "script=.\build_server.bat -d"
    goto :missing_server
  ) else (
    goto :server_build_exists
  )
)

:missing_server
echo.
echo      Exiting...
echo.
echo      The %serverType% server does not exist. Run `%script%`, then re-run this script.
echo.
exit

:server_build_exists

echo.
:choice
IF "%askIfOff%"=="-s" (
  goto :server_off
) ELSE (
  set /P c=Is the server off? [Y/n]: 
)
if /I "%c%" EQU "" goto :server_off
if /I "%c%" EQU "Y" goto :server_off
if /I "%c%" EQU "N" goto :server_on
echo "%c%" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit.
goto :choice

:server_on
echo.
echo      Exiting...
echo.
echo      If the server is on, turn it off by exiting the terminal window or app where it is running, then re-run this script.
echo.
exit

:server_off

REM Identify if app_setup has already been run, and run it anything is missing.
if not exist ..\..\buildSpec.json set runSetup=1
if not exist ..\..\globalBuildResources\i18nPatch.json set runSetup=1
if not exist ..\..\globalBuildResources\product.json set runSetup=1
if not exist ..\buildResources\setup\app_setup.json set runSetup=1
if defined %runSetup (
  cmd /c .\app_setup.bat
  echo.
  echo   +-----------------------------------------------------------------------------+
  echo   ^| Config files were rebuilt by `./app_setup.bsh` as one or more were missing. ^|
  echo   +-----------------------------------------------------------------------------+
  echo.
)

REM Ensure buildSpec.json has the location for the indicated server build type
@echo off
setlocal enabledelayedexpansion

set "configFile=..\..\buildSpec.json"
set "tmpFile=..\..\buildSpec.bak"
copy %configFile% %tmpFile%


(for /f "tokens=*" %%a in ('type "%tmpFile%" ^| findstr /n "^"') do (
    set "line=%%a"
    set "line=!line:*:=!"

    if defined line (
        set "line=!line:%search%=%replace%!"
        echo(!line!
    ) else echo.
)) > "%configFile%"

endlocal

REM set port environment variables
set ROCKET_PORT=19119

if exist ..\build (
  echo "Removing last build environment"
  rmdir ..\build /s /q
)
if not exist ..\build (
  echo "Assembling build environment"
  node build.js
)
echo "Running with local server in %serverType% mode..."
cd ..\build
SET APP_RESOURCES_DIR=.\lib\
start "" ".\bin\server.exe"