@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\build_server.bat

REM Do not ask if the server is off if the -s positional argument is provided in either #1 or #2
REM Debug server if the -d positional argument is provided in either #1 or #2
:loop
IF "%~1"=="" (
  goto :continue
) ELSE IF "%~1"=="-s" (
  set "askIfOff=%~1"
) ELSE IF "%~1"=="-d" (
  set "debugServer=%~1"
)
shift
goto :loop

:continue

REM Assign default value if -s is not present
if not defined %askIfOff (
  set "askIfOff=-yes"
)

REM Assign default value if -d is not present
if not defined %debugServer (
  set "debugServer=-no"
  set "buildCommand=cargo build --release"
  set "search=local_server/target/debug"
  set "replace=local_server/target/release"
  set "serverType=release"
) else if "%debugServer%"=="-d" (
  set "buildCommand=cargo build"
  set "search=local_server/target/release"
  set "replace=local_server/target/debug"
  set "serverType=debug"
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

if not exist ..\..\buildSpec.json set "runSetup=1"
if not exist ..\..\globalBuildResources\i18nPatch.json "set runSetup=1"
if not exist ..\..\globalBuildResources\product.json "set runSetup=1"
if not exist ..\buildResources\setup\app_setup.json "set runSetup=1"
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

REM Build the rust server of the specified build type
echo "Building local %serverType% server at /%replace% ..."
cd ..\..\local_server
echo "%buildCommand%"
%buildCommand%
cd ..\windows\scripts

REM Clean the build environment
if exist ..\build (
  echo Removing last build environment
  rmdir ..\build /s /q
)

REM Assemble the build environment
if not exist ..\build (
  echo "Assembling build environment..."
  node build.js
)
