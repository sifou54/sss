@echo off
:: Check if running as admin
fsutil dirty query %systemdrive% >nul
if %errorlevel% neq 0 (
    echo This script must be run as administrator.
    pause
    exit /b
)
echo.
echo.
echo Cleaning WinSxS Folder
echo.
echo.
DISM /online /Cleanup-Image /StartComponentCleanup /ResetBase
pause