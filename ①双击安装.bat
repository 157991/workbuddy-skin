@echo off
chcp 65001 >nul
echo ========================================
echo   WorkBuddy Skin Studio - Install
echo ========================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1"
