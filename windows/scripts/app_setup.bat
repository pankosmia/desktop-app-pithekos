@echo off

echo.
echo      ****************************************************
echo      * This script uses \app_config.env                 *
echo      * to generate/rebuild/replace:                     *
echo      *   - \windows\buildResources\setup\app_setup.json *
echo      *   - \macos\buildResources\setup\app_setup.json   *
echo      *   - \linux\buildResources\setup\app_setup.json   *
echo      *   - \buildSpec.json                              *
echo      *   - \globalBuildResources\i18nPatch.json         *
echo      *   - \globalBuildResources\product.json           *
echo      ****************************************************
echo.

for /F "tokens=1,2 delims==" %%a in (..\..\app_config.env) do set %%a=%%b

setlocal ENABLEDELAYEDEXPANSION

set "clients=..\buildResources\setup\app_setup.json"
set "spec=..\..\buildSpec.json"
set "name=..\..\globalBuildResources\i18nPatch.json"
set "product=..\..\globalBuildResources\product.json"

echo {> %name%
echo   "branding": {>> %name%
echo     "software": {>> %name%
echo       "name": {>> %name%
echo         "en": "%APP_NAME:'=%">> %name%
echo       }>> %name%
echo     }>> %name%
echo   }>> %name%
echo }>> %name%

echo {> %spec%
echo   "app": {>> %spec%
echo     "name": "%APP_NAME:'=%",>> %spec%
echo     "version": "%APP_VERSION%">> %spec%
echo   },>> %spec%

echo   "bin": {>> %spec%
echo     "src": "../../local_server/target/release/local_server">> %spec%
echo   },>> %spec%

echo   "lib": [>> %spec%
set "count=0"
for /f "tokens=*" %%a in (..\..\app_config.env) do (
  set /a count+= 1
)
for /l %%a in (1,1,%count%) do (
  if "!ASSET%%a!" NEQ "" (
    REM Remove any spaces, e.g. trailing ones
    set ASSET%%a=!ASSET%%a: =!
    echo     {>> %spec%
    set src=      "src": "../../../!ASSET%%a!
  )
  if "!ASSET%%a_PATH!" NEQ "" (
    REM Remove any spaces, e.g. trailing ones
    set ASSET%%a_PATH=!ASSET%%a_PATH: =!
    set src=!src!!ASSET%%a_PATH!",
    echo !src!>> %spec%
  )
  if "!ASSET%%a_NAME!" NEQ "" (
    REM Remove any spaces, e.g. trailing ones
    set ASSET%%a_NAME=!ASSET%%a_NAME: =!
    echo       "targetName": "!ASSET%%a_NAME!">> %spec%
    echo     },>> %spec%
  )
)
echo     {>> %spec%
echo       "src": "../buildResources/setup",>> %spec%
echo       "targetName": "setup">> %spec%
echo     }>> %spec%
echo    ],>> %spec%

echo   "libClients": [>> %spec%
echo {> %clients%
echo   "clients": [>> %clients%

REM Get total number of clients
set "clientcount=0"
for /l %%a in (1,1,%count%) do (
  if "!CLIENT%%a!" NEQ "" (
    set /a clientcount+= 1
  )
)
for /l %%a in (1,1,%count%) do (
  if "!CLIENT%%a!" NEQ "" (
    REM Remove any spaces, e.g. trailing ones
    set CLIENT%%a=!CLIENT%%a: =!
    echo     {>> %clients%
    echo       "path": "%%%%PANKOSMIADIR%%%%/!CLIENT%%a!">> %clients%
    if %%a==%clientcount% (
      echo     "../../../!CLIENT%%a!">> %spec%
      echo     }>> %clients%
    ) else (
      echo     "../../../!CLIENT%%a!",>> %spec%
      echo     },>> %clients%
    )
  )
)
echo   ]>> %clients%
echo }>> %clients%

rem get LocalDateTime from PowerShell (WMIC is deprecated thus not not available on windows-2025 runner)
for /f "delims=" %%I in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMddHHmmss')"') do set "ldt=%%I"

set yyyy=%ldt:~0,4%
set mm=%ldt:~4,2%
set dd=%ldt:~6,2%
set hh=%ldt:~8,2%
set min=%ldt:~10,2%
set ss=%ldt:~12,2%

rem Convert month number to short name
if "%mm%"=="01" set mname=Jan
if "%mm%"=="02" set mname=Feb
if "%mm%"=="03" set mname=Mar
if "%mm%"=="04" set mname=Apr
if "%mm%"=="05" set mname=May
if "%mm%"=="06" set mname=Jun
if "%mm%"=="07" set mname=Jul
if "%mm%"=="08" set mname=Aug
if "%mm%"=="09" set mname=Sep
if "%mm%"=="10" set mname=Oct
if "%mm%"=="11" set mname=Nov
if "%mm%"=="12" set mname=Dec

rem Get timezone offset (HHMM) from registry and format as ±HH:MM
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v Bias 2^>nul') do set Bias=%%B
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v DaylightBias 2^>nul') do set DaylightBias=%%B

rem Use Bias + DaylightBias when daylight saving is active; try to detect by StandardName vs DaylightName times
rem Bias = minutes west of UTC (positive means UTC-)
if not defined Bias set "Bias=0"
set /a tzMinutes=Bias

rem Determine sign and absolute minutes, then convert to hours:minutes
if %tzMinutes% GEQ 0 (
  set "sign=-"
) else (
  set "sign=+"
  set /a tzMinutes=-tzMinutes
)
set /a tzH=tzMinutes/60
set /a tzM=tzMinutes%%60
if %tzH% LSS 10 set "tzH=0%tzH%"
if %tzM% LSS 10 set "tzM=0%tzM%"
set tz=%sign%%tzH%:%tzM%

echo {>%product%
echo   "name": "%APP_NAME:'=%",>> %product%
echo   "short_name": "%APP_SHORT_NAME%",>> %product%
echo   "version": "%APP_VERSION%",>> %product%
echo   "datetime": "%dd% %mname% %yyyy% %hh%:%min%:%ss% UTC%tz%">> %product%
echo }>> %product%

echo   ],>> %spec%
echo   "favIcon": "../../globalBuildResources/favicon.ico",>> %spec%
echo   "theme": "../../globalBuildResources/theme.json",>> %spec%
echo   "product": "../../globalBuildResources/product.json",>> %spec%
echo   "client_config": "../../globalBuildResources/client_config.json">> %spec%
echo }>> %spec%

echo.
echo \buildSpec.json generated/rebuilt/replaced
echo \globalBuildResources\i18nPatch.json generated/rebuilt/replaced
echo \globalBuildResources\product.json generated/rebuilt/replaced
echo \windows\buildResources\setup\app_setup.json generated/rebuilt/replaced
echo.
echo Copying \windows\buildResources\setup\app_setup.json to \linux\buildResources\setup\
copy ..\buildResources\setup\app_setup.json ..\..\linux\buildResources\setup\app_setup.json
echo Copying \windows\buildResources\setup\app_setup.json to \macos\buildResources\setup\
copy ..\buildResources\setup\app_setup.json ..\..\macos\buildResources\setup\app_setup.json

endlocal