@echo off

REM 1. Create win_icon.svg or win_icon.png source file ≥ 1024px square, and place it in the `source` subdirectory, one level down from `branding`.
REM 2. Run this script in a terminal by entering: `.\winicon.bat [inkscape|imagemagick|magick] [svg|png]` from the `branding` directory.
REM    - Arguments can be provided in any order
REM    - If arguments are not provided, you will be prompted if needed
REM Re-running this script over-writes files it just created (or any other files of the same names).

REM win_icon_*.png files are building blocks for icon.ico (Windows icon format)
REM linux_icon.png is for Linux Application Menu/Desktop. It is places in the globalBuildResources directory.

setlocal enabledelayedexpansion

set SOURCE_FORMAT=
set CONVERSION_TOOL=

REM Parse arguments in any order
:parse_args
if "%~1"=="" goto check_args
set ARG=%~1
if /i "%ARG%"=="png" set SOURCE_FORMAT=png
if /i "%ARG%"=="svg" set SOURCE_FORMAT=svg
if /i "%ARG%"=="magick" set CONVERSION_TOOL=magick
if /i "%ARG%"=="imagemagick" set CONVERSION_TOOL=magick
if /i "%ARG%"=="inkscape" set CONVERSION_TOOL=inkscape
shift
goto parse_args

:check_args
REM Detect which tools are installed
set MAGICK_INSTALLED=0
set INKSCAPE_INSTALLED=0
set INKSCAPE_CMD=inkscape
set INKSCAPE_PATH=

magick -version >nul 2>&1
if %ERRORLEVEL%==0 set MAGICK_INSTALLED=1

REM Check if inkscape is in PATH first
inkscape --version >nul 2>&1
if %ERRORLEVEL%==0 (
    set INKSCAPE_INSTALLED=1
    set INKSCAPE_CMD=inkscape
) else (
    REM Check common installation locations
    if exist "C:\Program Files\Inkscape\bin\inkscape.exe" set "INKSCAPE_PATH=C:\Program Files\Inkscape\bin\inkscape.exe"
    if exist "C:\Program Files (x86)\Inkscape\bin\inkscape.exe" set "INKSCAPE_PATH=C:\Program Files (x86)\Inkscape\bin\inkscape.exe"
    
    REM Use a temporary variable to avoid parentheses issues
    set "LOCALAPP_INKSCAPE=%LOCALAPPDATA%\Programs\Inkscape\bin\inkscape.exe"
    if exist "!LOCALAPP_INKSCAPE!" set "INKSCAPE_PATH=!LOCALAPP_INKSCAPE!"
    
    set "PF_INKSCAPE=%ProgramFiles%\Inkscape\bin\inkscape.exe"
    if exist "!PF_INKSCAPE!" if not defined INKSCAPE_PATH set "INKSCAPE_PATH=!PF_INKSCAPE!"
    
    REM Handle ProgramFiles(x86) by using the environment variable directly in a separate variable
    call set "PFX86_INKSCAPE=%%ProgramFiles(x86)%%\Inkscape\bin\inkscape.exe"
    if exist "!PFX86_INKSCAPE!" if not defined INKSCAPE_PATH set "INKSCAPE_PATH=!PFX86_INKSCAPE!"
    
    if defined INKSCAPE_PATH (
        set INKSCAPE_INSTALLED=1
        set "INKSCAPE_CMD=!INKSCAPE_PATH!"
        for %%I in ("!INKSCAPE_PATH!") do set "INKSCAPE_BIN_DIR=%%~dpI"
        REM Remove trailing backslash
        if "!INKSCAPE_BIN_DIR:~-1!"=="\" set "INKSCAPE_BIN_DIR=!INKSCAPE_BIN_DIR:~0,-1!"
        echo.
        echo Inkscape is not in your PATH, though was found Inkscape at: !INKSCAPE_PATH!
        echo.
        echo While not necessary for this script, if you want to use Inkscape CLI yourself then add this directory to your PATH:
        echo       !INKSCAPE_BIN_DIR!
    )
)

set PNG_EXISTS=0
set SVG_EXISTS=0
if exist "source\win_icon.png" set PNG_EXISTS=1
if exist "source\win_icon.svg" set SVG_EXISTS=1

if not "%SOURCE_FORMAT%"=="" goto validate_format

if %PNG_EXISTS%==0 if %SVG_EXISTS%==0 (
    echo Error: No source file found. Please create either source\win_icon.png or source\win_icon.svg, ≥ 1024px square.
    exit /b 1
)

REM Auto-select if only one source exists
if %SVG_EXISTS%==1 if %PNG_EXISTS%==0 (
    set SOURCE_FORMAT=svg
    goto validate_format
)
if %PNG_EXISTS%==1 if %SVG_EXISTS%==0 (
    set SOURCE_FORMAT=png
    goto validate_format
)

REM Both files exist - prompt user
:prompt_format
echo.
echo Select source format:
echo   1. SVG ^(default^)
echo   2. PNG
echo.
set /p FORMAT_CHOICE="Enter choice (1 or 2, press Enter for default): "
if "!FORMAT_CHOICE!"=="" set SOURCE_FORMAT=svg& goto validate_format
if "!FORMAT_CHOICE!"=="1" set SOURCE_FORMAT=svg& goto validate_format
if "!FORMAT_CHOICE!"=="2" set SOURCE_FORMAT=png& goto validate_format
echo "!FORMAT_CHOICE!" is not a valid response. Please type 1, 2, or 'Enter' to continue.
goto prompt_format

:validate_format
if "%SOURCE_FORMAT%"=="" (
    if exist "source\win_icon.svg" (
        set SOURCE_FORMAT=svg
    ) else if exist "source\win_icon.png" (
        set SOURCE_FORMAT=png
    )
)

if /i not "%SOURCE_FORMAT%"=="png" if /i not "%SOURCE_FORMAT%"=="svg" (
    echo Error: Invalid source format. Must be 'png' or 'svg'.
    exit /b 1
)

set SOURCE_FILE=source\win_icon.%SOURCE_FORMAT%
if not exist "%SOURCE_FILE%" (
    echo Error: Source file not found: %SOURCE_FILE%
    if /i "%SOURCE_FORMAT%"=="png" (
        if exist "source\win_icon.svg" (
            echo Note: source\win_icon.svg exists. Did you mean to use SVG format?
        )
    ) else (
        if exist "source\win_icon.png" (
            echo Note: source\win_icon.png exists. Did you mean to use PNG format?
        )
    )
    exit /b 1
)

if not "%CONVERSION_TOOL%"=="" goto validate_tool

if /i "%SOURCE_FORMAT%"=="png" (
    REM PNG requires ImageMagick
    if %MAGICK_INSTALLED%==0 (
        echo Error: ImageMagick is required for PNG sources but is not installed.
        echo Please install ImageMagick from https://imagemagick.org/
        exit /b 1
    )
    set CONVERSION_TOOL=magick
    goto validate_tool
)

REM SVG source - check what tools are available
if %MAGICK_INSTALLED%==0 if %INKSCAPE_INSTALLED%==0 (
    echo Error: No conversion tools found. Please install at least one of:
    echo   - ImageMagick: https://imagemagick.org/
    echo   - Inkscape: https://inkscape.org/
    exit /b 1
)

if %MAGICK_INSTALLED%==0 if %INKSCAPE_INSTALLED%==1 (
    echo Error: Please install ImageMagick. It is used by this script to package a multi-resolution ico file.:
    echo   - ImageMagick: https://imagemagick.org/
    exit /b 1
)

REM Build menu based on available tools - Inkscape first (preferred for SVG)
set MENU_COUNT=0
set MENU_1=
set MENU_2=
set MENU_3=
set TOOL_1=
set TOOL_2=
set TOOL_3=

if %INKSCAPE_INSTALLED%==1 (
    set /a MENU_COUNT+=1
    set MENU_!MENU_COUNT!=Inkscape ^(default - slow, with better rendering quality for complex vector SVGs^)
    set TOOL_!MENU_COUNT!=inkscape
    set DEFAULT_TOOL=inkscape
)

if %MAGICK_INSTALLED%==1 (
    set /a MENU_COUNT+=1
    set MENU_!MENU_COUNT!=ImageMagick
    set TOOL_!MENU_COUNT!=magick
    if not defined DEFAULT_TOOL set DEFAULT_TOOL=magick
)

REM If only one tool available, auto-select it
if %MENU_COUNT%==1 (
    set CONVERSION_TOOL=!TOOL_1!
    goto validate_tool
)

:prompt_tool
echo.
echo Select conversion tool for SVG:
if defined MENU_1 echo   1. !MENU_1!
if defined MENU_2 echo   2. !MENU_2!
if defined MENU_3 echo   3. !MENU_3!
echo.
set /p TOOL_CHOICE="Enter choice (1-!MENU_COUNT!, press Enter for default): "

if "!TOOL_CHOICE!"=="" set CONVERSION_TOOL=!DEFAULT_TOOL!& goto validate_tool
if "!TOOL_CHOICE!"=="1" if defined TOOL_1 set CONVERSION_TOOL=!TOOL_1!& goto validate_tool
if "!TOOL_CHOICE!"=="2" if defined TOOL_2 set CONVERSION_TOOL=!TOOL_2!& goto validate_tool
if "!TOOL_CHOICE!"=="3" if defined TOOL_3 set CONVERSION_TOOL=!TOOL_3!& goto validate_tool

if %MENU_COUNT%==2 (
    echo "!TOOL_CHOICE!" is not a valid response. Please type 1, 2, or 'Enter' to continue.
) else (
    echo "!TOOL_CHOICE!" is not a valid response. Please type 1, 2, 3, or 'Enter' to continue.
)
goto prompt_tool

:validate_tool
if "%CONVERSION_TOOL%"=="" set CONVERSION_TOOL=!DEFAULT_TOOL!

REM Validate that the selected tool is actually installed
if /i "%CONVERSION_TOOL%"=="magick" if %MAGICK_INSTALLED%==0 (
    echo Error: ImageMagick is not installed. Please install it from https://imagemagick.org/
    exit /b 1
)
if /i "%CONVERSION_TOOL%"=="inkscape" if %INKSCAPE_INSTALLED%==0 (
    echo Error: Inkscape is not installed. Please install it from https://inkscape.org/
    exit /b 1
)

if /i not "%CONVERSION_TOOL%"=="magick" if /i not "%CONVERSION_TOOL%"=="inkscape" (
    echo Error: Invalid conversion tool. Must be 'magick' or 'inkscape'.
    exit /b 1
)

if /i "%SOURCE_FORMAT%"=="png" (
    if /i "%CONVERSION_TOOL%"=="inkscape" (
        echo Error: Inkscape can only be used with SVG sources. Use 'magick' for PNG sources.
        exit /b 1
    )
)

echo.
echo Using source format: %SOURCE_FORMAT%
echo Using conversion tool: %CONVERSION_TOOL%
echo Source file: %SOURCE_FILE%
echo.
echo Generating icon files...
if "%CONVERSION_TOOL%"=="inkscape" (
  echo.
  echo Inkscape is a complete GUI application that loads its entire rendering engine, even when run from command line.
  echo Please wait patiently...
)
echo.

REM Generate all icon sizes
if /i "%SOURCE_FORMAT%"=="png" (
    magick %SOURCE_FILE% -filter Lanczos -resize 16x16 building_blocks\for_icon_ico\win_icon_16x16.png
    magick %SOURCE_FILE% -filter Lanczos -resize 32x32 building_blocks\for_icon_ico\win_icon_32x32.png
    magick %SOURCE_FILE% -filter Lanczos -resize 48x48 building_blocks\for_icon_ico\win_icon_48x48.png
    magick %SOURCE_FILE% -filter Lanczos -resize 256x256 building_blocks\for_icon_ico\win_icon_256x256.png
) else (
    if /i "%CONVERSION_TOOL%"=="magick" (
        magick -background none MSVG:%SOURCE_FILE% -filter Lanczos -resize 16x16 building_blocks\for_icon_ico\win_icon_16x16.png
        magick -background none MSVG:%SOURCE_FILE% -filter Lanczos -resize 32x32 building_blocks\for_icon_ico\win_icon_32x32.png
        magick -background none MSVG:%SOURCE_FILE% -filter Lanczos -resize 48x48 building_blocks\for_icon_ico\win_icon_48x48.png
        magick -background none MSVG:%SOURCE_FILE% -filter Lanczos -resize 256x256 building_blocks\for_icon_ico\win_icon_256x256.png
    ) else if /i "%CONVERSION_TOOL%"=="inkscape" (
        "!INKSCAPE_CMD!" %SOURCE_FILE% --export-filename=building_blocks\for_icon_ico\win_icon_16x16.png --export-width=16 --export-height=16
        "!INKSCAPE_CMD!" %SOURCE_FILE% --export-filename=building_blocks\for_icon_ico\win_icon_32x32.png --export-width=32 --export-height=32
        "!INKSCAPE_CMD!" %SOURCE_FILE% --export-filename=building_blocks\for_icon_ico\win_icon_48x48.png --export-width=48 --export-height=48
        "!INKSCAPE_CMD!" %SOURCE_FILE% --export-filename=building_blocks\for_icon_ico\win_icon_256x256.png --export-width=256 --export-height=256
    )
)

magick -verbose building_blocks\for_icon_ico\win_icon_16x16.png building_blocks\for_icon_ico\win_icon_32x32.png building_blocks\for_icon_ico\win_icon_48x48.png building_blocks\for_icon_ico\win_icon_256x256.png ..\globalBuildResources\icon.ico

REM For Linux
copy building_blocks\for_icon_ico\win_icon_256x256.png ..\globalBuildResources\linux_icon.png >nul

endlocal

echo.
echo ************************************************************************************************************
echo * Review rendering quality of smaller size icons.                                                          *
echo *      - See `for_icon_ico` directory                                                                      *
echo * Consider if smaller sizes need a different variation.                                                    *
echo *                                                                                                          *
echo * This script places its final product - `icon.ico` - in the `globalBuildResources` directory.             *
echo *                                                                                                          *
echo * NOTE: Re-running this script will over-write the same files it creates^!                                  *
echo *                                                                                                          *
echo * To recreate icon.ico from custom files, run this from the `for_icon_ico` directory:                      *
echo * `magick -verbose win_icon_16x16.png win_icon_32x32.png win_icon_48x48.png win_icon_256x256.png icon.ico` *
echo *                                                                                                          *
echo * To recreate linux Application Menu/Desktop png, manually change globalBuildResources\linux_icon.png      *
echo *      - The script has set that at 256x256 pixels.  Use a different resolution if preferred.              *
echo *      -  Multiple png resolutions or svg are not supported by workflow scripts as currently provided.     *
echo ************************************************************************************************************
echo.
