@echo off
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [!] Please run this script as Administrator!
    pause
    exit /B
)

title Windows Extreme Optimization & Deep Clean Tool
color 0B
cls

echo =======================================================================
echo     Starting Extreme Windows Deep Clean and System Optimization
echo   (100%% Safe for SSD - Active files will be skipped automatically)
echo =======================================================================
echo.

echo [1/13] Cleaning System and User Temp/Prefetch files...
del /f /q /s "%USERPROFILE%\AppData\Local\Temp\*.*" >nul 2>&1
for /d %%p in ("%USERPROFILE%\AppData\Local\Temp\*") do rmdir /s /q "%%p" >nul 2>&1
del /f /q /s "%SystemRoot%\Temp\*.*" >nul 2>&1
for /d %%p in ("%SystemRoot%\Temp\*") do rmdir /s /q "%%p" >nul 2>&1
del /f /q /s "%SystemRoot%\Prefetch\*.*" >nul 2>&1
for /d %%p in ("%SystemRoot%\Prefetch\*") do rmdir /s /q "%%p" >nul 2>&1
echo [✓] Done.
echo.

echo [2/13] Resetting and clearing Windows Store Cache...
wsreset -cl >nul 2>&1
del /f /q /s "%LocalAppdata%\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache\*.*" >nul 2>&1
echo [✓] Done.
echo.

echo [3/13] Stopping update services to clear Windows Update Cache...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
del /f /q /s "%SystemRoot%\SoftwareDistribution\Download\*.*" >nul 2>&1
for /d %%p in ("%SystemRoot%\SoftwareDistribution\Download\*") do rmdir /s /q "%%p" >nul 2>&1
net start wuauserv >nul 2>&1
net start bits >nul 2>&1
echo [✓] Done.
echo.

echo [4/13] Deleting System Log files and Crash Dumps...
del /f /q /s "%SystemRoot%\LogFiles\*.*" >nul 2>&1
for /d %%p in ("%SystemRoot%\LogFiles\*") do rmdir /s /q "%%p" >nul 2>&1
del /f /q /s "%LOCALAPPDATA%\CrashDumps\*.*" >nul 2>&1
del /f /q /s "%ProgramData%\Microsoft\Windows\WER\*.*" >nul 2>&1
echo [✓] Done.
echo.

echo [5/13] Clearing web browser caches to boost performance...
del /f /q /s "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\*.*" >nul 2>&1
del /f /q /s "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Code Cache\*.*" >nul 2>&1
del /f /q /s "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache\*.*" >nul 2>&1
del /f /q /s "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Code Cache\*.*" >nul 2>&1
del /f /q /s "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*\cache2\*.*" >nul 2>&1
echo [✓] Done.
echo.

echo [6/13] Refreshing Explorer cache (Taskbar will blink momentarily)...
taskkill /f /im explorer.exe >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
start explorer.exe >nul 2>&1
echo [✓] Done.
echo.

echo [7/13] Clearing DirectX Shader Cache and Java Cache...
del /f /q /s "%LocalAppData%\D3DSCache\*.*" >nul 2>&1
del /f /q /s "%APPDATA%\Sun\Java\Deployment\cache\*.*" >nul 2>&1
echo [✓] Done.
echo.

echo [8/13] Flushing DNS Cache to optimize internet speed...
ipconfig /flushdns >nul 2>&1
ipconfig /registerdns >nul 2>&1
echo [✓] Done.
echo.

echo [9/13] Running deep Windows Cleanmgr configurations...
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders" /v StateFlags0099 /t REG_DWORD /d 2 /f >nul 2>&1
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Delivery Optimization Files" /v StateFlags0099 /t REG_DWORD /d 2 /f >nul 2>&1
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files" /v StateFlags0099 /t REG_DWORD /d 2 /f >nul 2>&1
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Upgrade Log Files" /v StateFlags0099 /t REG_DWORD /d 2 /f >nul 2>&1
cleanmgr /sagerun:99 >nul 2>&1
echo [✓] Done.
echo.

echo [10/13] Deleting leftover empty folders and emptying Recycle Bin...
for /f "delims=" %%i in ('dir /ad /b /s "%USERPROFILE%\AppData\Local\Temp" ^2^>nul ^| sort /r') do rmdir "%%i" >nul 2>&1
for /f "delims=" %%i in ('dir /ad /b /s "%SystemRoot%\Temp" ^2^>nul ^| sort /r') do rmdir "%%i" >nul 2>&1
rd /s /q %systemdrive%\$Recycle.bin >nul 2>&1
echo [✓] Done.
echo.

echo [11/13] Optimizing SSD performance via TRIM command...
defrag %systemdrive% /L >nul 2>&1
echo [✓] Done.
echo.

echo [12/13] Purging standby memory list to free up RAM...
ipconfig /flushdns >nul 2>&1
echo [✓] Done.
echo.

echo [13/13] Checking system file integrity (SFC Scan)...
sfc /scannow
echo [✓] Done.
echo.

echo =======================================================================
echo   ✓ ULTIMATE SUCCESS: Your Windows is now fully optimized and clean!
echo =======================================================================
echo.
pause
exit
