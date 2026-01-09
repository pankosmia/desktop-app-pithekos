@echo off

REM set available port environment variable (returned as %ROCKET_PORT% )
call .\find_free_port.bat

SET APP_RESOURCES_DIR=.\lib\

start "" "%~dp0\bin\server.exe"

timeout /t 1 /nobreak >nul

REM Check if Firefox is installed by looking for the executable
SET URL=http://localhost:19119
SET FIREFOX_PATH="%ProgramFiles%\Mozilla Firefox\firefox.exe"
IF EXIST %FIREFOX_PATH% (
    REM Launch Firefox with the specified URL
    start "" %FIREFOX_PATH% %URL%
) ELSE (
    SET FIREFOX_PATH="C:\Program Files\Mozilla Firefox\firefox.exe"
    IF EXIST %FIREFOX_PATH% (
        REM Launch Firefox with the specified URL
        start "" %FIREFOX_PATH%  %URL%
    ) ELSE (
        SET FIREFOX_PATH="C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
        IF EXIST %FIREFOX_PATH% (
            REM Launch Firefox with the specified URL
            start "" %FIREFOX_PATH%  %URL%
        ) ELSE (
            REM Launch the default browser with the specified URL
            start ""  %URL%
        )
    )
)

exit
