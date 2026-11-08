@echo off
rem Publish this repository to GitHub (no GitHub CLI required).
setlocal
set "PS1=%~dp0scripts\publish-to-github.ps1"
if not exist "%PS1%" (
    echo [ERROR] scripts\publish-to-github.ps1 not found.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
endlocal
