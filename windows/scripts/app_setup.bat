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
echo      ****************************************************
echo.

for /F "tokens=1,2 delims==" %%a in (..\..\app_config.env) do set %%a=%%b

setlocal ENABLEDELAYEDEXPANSION

set clients=..\buildResources\setup\app_setup.json
set spec=..\..\buildSpec.json
set name=..\..\globalBuildResources\i18nPatch.json

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
set count=0
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
set clientcount=0
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
echo   ],>> %clients%
echo   "app": {>> %clients%
echo     "name": "%APP_NAME:'=%",>> %clients%
echo     "version": "%APP_VERSION%",>> %clients%
echo     "short_name": "%APP_SHORT_NAME%">> %clients%
echo   }>> %clients%
echo }>> %clients%

echo   ],>> %spec%
echo   "favIcon": "../../globalBuildResources/favicon.ico",>> %spec%
echo   "theme": "../../globalBuildResources/theme.json">> %spec%
echo }>> %spec%

echo.
echo \buildSpec.json generated/rebuilt/replaced
echo \globalBuildResources\i18nPatch.json generated/rebuilt/replaced
echo \windows\buildResources\setup\app_setup.json generated/rebuilt/replaced
echo.
echo Copying \windows\buildResources\setup\app_setup.json to \linux\buildResources\setup\
copy ..\buildResources\setup\app_setup.json ..\..\linux\buildResources\setup\app_setup.json
echo Copying \windows\buildResources\setup\app_setup.json to \macos\buildResources\setup\
copy ..\buildResources\setup\app_setup.json ..\..\macos\buildResources\setup\app_setup.json

endlocal