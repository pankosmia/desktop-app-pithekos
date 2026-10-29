@echo off
pushd "%~dp0"

echo Launching %%APP_NAME%% in another window...
cmd /c start "" "%~dp0%%APP_NAME%%\electron\electron.exe" "%~dp0%%APP_NAME%%\electron"
timeout /t 4 /nobreak >nul

popd
exit
