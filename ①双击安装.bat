@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================
echo   WorkBuddy Skin Studio Install
echo ========================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts\install.ps1"
