@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\build_server.bat

REM Do not ask if the server is off if the -s positional argument is provided
REM Debug server if the -d positional argument is provided
REM Specify environment as first non-flag positional argument: dev, qa, or main (default: main)
set "envArg="
:loop
IF "%~1"=="" (
  goto :continue
)
IF "%~1"=="-s" (
  set "askIfOff=%~1"
  shift
  goto :loop
)
IF "%~1"=="-d" (
  set "debugServer=%~1"
  shift
  goto :loop
)
IF not defined envArg (
  IF "%~1"=="dev" set "envArg=dev"
  IF "%~1"=="qa" set "envArg=qa"
  IF "%~1"=="main" set "envArg=main"
)
shift
goto :loop

:continue

REM Normalize: anything other than dev or qa is treated as main
if not defined envArg (
  set "envArg=main"
)
if /I not "%envArg%"=="dev" if /I not "%envArg%"=="qa" (
  set "envArg=main"
)

REM For dev and qa, back up Cargo.toml and rewrite the pankosmia_web version
REM For main, Cargo.toml already has the correct version — no replacement needed
set "cargoFile=..\..\local_server\Cargo.toml"
set "cargoBackup=..\..\local_server\Cargo.toml.bak"
set "didRewrite=0"

if /I not "%envArg%"=="main" (
  setlocal enabledelayedexpansion
  set "targetVersion="
  for /f "tokens=1,* delims==" %%a in ('type "..\..\local_server.env"') do (
    if /I "%%a"=="%envArg%" (
      set "targetVersion=%%b"
    )
  )
  if not defined targetVersion (
    echo.
    echo      Could not find environment "%envArg%" in local_server.env
    echo.
    exit /b 1
  )
  echo.
  echo   Using pankosmia_web version !targetVersion! for environment "%envArg%"

  copy "!cargoFile!" "!cargoBackup!" >nul

  set "cargoTmp=..\..\local_server\Cargo.toml.tmp"
  (for /f "usebackq tokens=*" %%a in ("!cargoBackup!") do (
    set "line=%%a"
    echo !line! | findstr /C:"pankosmia_web" >nul
    if !errorlevel! equ 0 (
      echo pankosmia_web = "=!targetVersion!"
    ) else (
      echo(!line!
    )
  )) > "!cargoTmp!"
  move /y "!cargoTmp!" "!cargoFile!" >nul

  endlocal
  set "didRewrite=1"
) else (
  echo.
  echo   Using pankosmia_web version from Cargo.toml ^(main^)
)

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
REM Restore Cargo.toml if it was rewritten
if "%didRewrite%"=="1" (
  copy "..\..\local_server\Cargo.toml.bak" "..\..\local_server\Cargo.toml" >nul
  del "..\..\local_server\Cargo.toml.bak"
)
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
set "buildResult=%errorlevel%"
cd ..\windows\scripts

REM Restore Cargo.toml if it was rewritten
if "%didRewrite%"=="1" (
  copy "..\..\local_server\Cargo.toml.bak" "..\..\local_server\Cargo.toml" >nul
  del "..\..\local_server\Cargo.toml.bak"
)

REM Exit if the build failed
if not "%buildResult%"=="0" (
  echo.
  echo      Build failed with exit code %buildResult%.
  echo.
  exit /b %buildResult%
)

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
