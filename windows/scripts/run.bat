@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\run.bat
REM Optional argument: `.\run.bat -s` to pre-confirm the server is off, so as to not be asked.

REM Do not ask if the server is off if the -s positional argument is provided
:loop
IF "%~1"=="" (
  goto :continue
) ELSE IF "%~1"=="-s" (
  set "askIfOff=%~1"
)
shift
goto :loop

:continue

REM Assign default value if -s is not present
if not defined askIfOff (
  set "askIfOff=-yes"
)

if not exist ..\..\local_server\target\release\local_server.exe (
  echo.
  echo      Exiting...
  echo.
  echo      The local server does not exist. Run `.\build_server.bat`, then re-run this script.
  echo.
  exit
)

echo.
:choice
IF "%askIfOff%"=="-s" (
  goto :server_off
) ELSE (
  set /P "c=Is the server off? [Y/n]: "
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
if not exist ..\..\buildSpec.json set "runSetup=1"
if not exist ..\..\globalBuildResources\i18nPatch.json set "runSetup=1"
if not exist ..\..\globalBuildResources\product.json set "runSetup=1"
if not exist ..\buildResources\setup\app_setup.json set "runSetup=1"
if defined runSetup (
  cmd /c .\app_setup.bat
  echo.
  echo   +-----------------------------------------------------------------------------+
  echo   ^| Config files were rebuilt by `.\app_setup.bat` as one or more were missing. ^|
  echo   +-----------------------------------------------------------------------------+
  echo.
)

REM set available port environment variable (returned as %ROCKET_PORT% )
call ..\buildResources\find_free_port.bat
echo Serving on port %ROCKET_PORT%...

if exist ..\build (
  echo Removing last build environment...
  rmdir ..\build /s /q
)
if not exist ..\build (
  echo Assembling build environment...
  node build.js
)
echo Running with local server in release mode...
cd ..\build
SET "APP_RESOURCES_DIR=.\lib\"
start "" cmd /k ".\bin\server.exe"