@echo off
title Professional Gaming Optimization Script
color 0B

:: 1. Check for Administrator Privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Administrator rights confirmed.
) else (
    color 0C
    echo [ERROR] Please run this script as Administrator!
    echo Right-click the .bat file and select "Run as administrator".
    pause
    exit
)

echo.
echo Creating System Restore Point (This may take a moment)...
wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "Pre-Gaming Optimization", 100, 7 >nul 2>&1
echo [OK] System Restore Point command sent.
echo.

:: 2. GPU & Display Optimizations
echo [1/13] Enabling HAGS (Hardware-Accelerated GPU Scheduling)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d "2" /f >nul

echo [2/13] Enabling Game Mode...
reg add "HKCU\Software\Microsoft\GameBar" /v "AllowAutoGameMode" /t REG_DWORD /d "1" /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d "1" /f >nul

echo [3/13] Disabling Game DVR...
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d "0" /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d "0" /f >nul

echo [4/13] Disabling Fullscreen Optimizations (Global)...
reg add "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehaviorMode" /t REG_DWORD /d "2" /f >nul
reg add "HKCU\System\GameConfigStore" /v "GameDVR_HonorUserFSEBehaviorMode" /t REG_DWORD /d "1" /f >nul
reg add "HKCU\System\GameConfigStore" /v "GameDVR_DXGIHonorFSEWindowsCompatible" /t REG_DWORD /d "1" /f >nul

echo [5/13] Increasing Shader Cache Size (10GB Limit via Environment Variables)...
setx GL_ShaderDiskCacheMaxCapacity 10240 /m >nul

echo [6/13] Disabling GameBar Presence Writer...
reg add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v "ActivationType" /t REG_DWORD /d "0" /f >nul

echo [7/13] Forcing Variable Refresh Rate (VRR)...
reg add "HKCU\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" /v "DirectXUserGlobalSettings" /t REG_SZ /d "VRR=1;" /f >nul

:: 3. CPU Optimizations
echo [8/13] Disabling Xbox Game Monitoring (xbgm)...
sc stop xbgm >nul 2>&1
sc config xbgm start= disabled >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\xbgm" /v "Start" /t REG_DWORD /d "4" /f >nul

echo [9/13] Disabling Core Parking (100%% Unparked for performance)...
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 >nul
powercfg -setactive SCHEME_CURRENT >nul

echo [10/13] Disabling Efficiency Mode (Power Throttling)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v "PowerThrottlingOff" /t REG_DWORD /d "1" /f >nul

echo [11/13] Disabling HPET and Dynamic Tick (Micro-stutter fix)...
bcdedit /deletevalue useplatformclock >nul 2>&1
bcdedit /set useplatformclock No >nul 2>&1
bcdedit /set disabledynamictick Yes >nul 2>&1

:: 4. RAM & System Optimizations
echo [12/13] Disabling Fast Startup (Clean RAM flush on reboot)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t REG_DWORD /d "0" /f >nul

echo [13/13] Disabling SysMain and Windows Search...
sc stop SysMain >nul 2>&1
sc config SysMain start= disabled >nul 2>&1
sc stop WSearch >nul 2>&1
sc config WSearch start= disabled >nul 2>&1

echo.
color 0A
echo ==========================================================
echo [SUCCESS] All optimizations applied successfully!
echo Please restart your PC for all changes to take effect.
echo ==========================================================
pause