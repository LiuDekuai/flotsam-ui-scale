@echo off
rem Flotsam UI Scale 150%% - installer launcher.
rem Requests administrator rights through scripts\run-elevated.ps1.
setlocal
set "LAUNCHER=%~dp0scripts\run-elevated.ps1"
if not exist "%LAUNCHER%" (
    echo [ERROR] scripts\run-elevated.ps1 not found. Please extract the whole archive.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%" install %*
endlocal
