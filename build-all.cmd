@ECHO OFF

:: variables
SET BUILD_DIR=E:\Software\McAfee\EEDK\Builds
SET EEDK_EXE=E:\Software\McAfee\EEDK\EEDK.exe
SET CUR_DIR=%~dp0
SET CUR_DIR=%CUR_DIR:~0,-1%

:: delete old builds
DEL %BUILD_DIR%\VSCL*.* /Q

:: rebuild .EEDKs
FOR /F %%i IN ('DIR /B %CUR_DIR%\VSCL-*.eedk') DO (
    %EEDK_EXE% -Settings:"%%i"
)
