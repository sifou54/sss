@echo off
title Windows Ultimate Safe Cleaner
color 0A
cls

openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Please run this script as Administrator.
    pause
    exit
)

echo [1/12] Cleaning User and System Temp files...
del /s /f /q "%USERPROFILE%\AppData\Local\Temp\*.*" 2>nul
del /s /f /q "%WINDIR%\Temp\*.*" 2>nul
del /s /f /q "%LOCALAPPDATA%\Temp\*.*" 2>nul

echo [2/12] Removing empty folders from Temp...
powershell -NoProfile -Command "Get-ChildItem -Path $env:TEMP -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { ($_.GetFileSystemInfos().Count -eq 0) } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue" >nul 2>&1
powershell -NoProfile -Command "Get-ChildItem -Path $env:WINDIR\Temp -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { ($_.GetFileSystemInfos().Count -eq 0) } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue" >nul 2>&1

echo [3/12] Cleaning Prefetch Cache...
del /s /f /q "%WINDIR%\Prefetch\*.*" 2>nul

echo [4/12] Cleaning Windows Update & Delivery Optimization Cache...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop dosvc >nul 2>&1
del /s /f /q "%WINDIR%\SoftwareDistribution\Download\*.*" 2>nul
for /d %%x in ("%WINDIR%\SoftwareDistribution\Download\*") do rd /s /q "%%x" 2>nul
del /s /f /q "%WINDIR%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*.*" 2>nul
net start dosvc >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1

echo [5/12] Cleaning DirectX and Shader Cache...
del /s /f /q "%LOCALAPPDATA%\NVIDIA\GLCache\*.*" 2>nul
del /s /f /q "%LOCALAPPDATA%\NVIDIA Corporation\NV_Cache\*.*" 2>nul
del /s /f /q "%LOCALAPPDATA%\AMD\GLCache\*.*" 2>nul
del /s /f /q "%LOCALAPPDATA%\D3DSCache\*.*" 2>nul
del /s /f /q "%LOCALAPPDATA%\Microsoft\DirectX Shader Cache\*.*" 2>nul

echo [6/12] Cleaning Icon and Thumbnail Cache...
del /s /f /q /a "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" 2>nul
del /s /f /q /a "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db" 2>nul
del /f /q /a "%LOCALAPPDATA%\IconCache.db" 2>nul

echo [7/12] Cleaning Crash Dumps and Error Reports...
del /f /q "%WINDIR%\Memory.dmp" 2>nul
del /s /f /q "%WINDIR%\Minidump\*.*" 2>nul
del /s /f /q "%LOCALAPPDATA%\Microsoft\Windows\WER\*.*" 2>nul
del /s /f /q "%WINDIR%\LiveKernelReports\*.*" 2>nul

echo [8/12] Cleaning Windows Event Logs...
for /F "tokens=*" %%G in ('wevtutil.exe el') DO (call :clear_log "%%G")
goto :continue_cleaning
:clear_log
wevtutil.exe cl %1 >nul 2>&1
goto :eof
:continue_cleaning

echo [9/12] Cleaning Store, Font, and Defender Scan Cache...
del /s /f /q "%WINDIR%\ServiceProfiles\LocalService\AppData\Local\FontCache\*.*" 2>nul
del /s /f /q "%LOCALAPPDATA%\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache\*.*" 2>nul
del /s /f /q "%ProgramData%\Microsoft\Windows Defender\Scans\History\Service\*.*" 2>nul

echo [10/12] Cleaning Recent Items and Quick Access Cache...
del /s /f /q "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Recent\*.*" 2>nul
del /s /f /q "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\*.*" 2>nul
del /s /f /q "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations\*.*" 2>nul

echo [11/12] Flushing Network and DNS Cache...
ipconfig /flushdns >nul 2>&1
arp -d * >nul 2>&1
nbtstat -R >nul 2>&1

echo [12/12] Emptying Recycle Bin and Clearing Clipboard...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
cmd /c "echo off | clip"

echo.
echo Complete! Windows cleaning completed successfully.
echo.
pause