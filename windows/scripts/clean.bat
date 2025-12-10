@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\clean.bat
REM Optional argument: .\clean.bat -s
REM To pre-confirm the server is off, so as to not be asked.

echo.
:choice
IF "%~1"=="-s" (
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
echo Cleaning...

if exist ..\build (
  echo Removing last build environment
  rmdir ..\build /s /q
)

set cleanServer=false

if exist ..\..\local_server\target\release\local_server.exe set cleanServer=true
if exist ..\..\local_server\target\debug\local_server.exe set cleanServer=true

if "%cleanServer%"=="true" (
  echo Cleaning local server
  cd ..\..\local_server
  cargo clean
  cd ..\windows\scripts
)

echo.
echo The local server and build environment have been cleaned.
echo.
