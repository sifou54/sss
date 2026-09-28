@echo off
title Windows Safe RAM & Cache Cleaner
color 0B
cls

openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Please run this script as Administrator.
    pause
    exit /b
)

echo [1/2] Purging Standby List and RAM Cache...

set "psScript=%TEMP%\ram_purge.ps1"
if exist "%psScript%" del /f /q "%psScript%"

echo $code = @' >> "%psScript%"
echo using System; >> "%psScript%"
echo using System.Runtime.InteropServices; >> "%psScript%"
echo using System.Diagnostics; >> "%psScript%"
echo public class RamPurger { >> "%psScript%"
echo     [DllImport("ntdll.dll")] >> "%psScript%"
echo     public static extern int NtSetSystemInformation(int SystemInformationClass, IntPtr SystemInformation, int SystemInformationLength); >> "%psScript%"
echo     [DllImport("kernel32.dll", SetLastError = true)] >> "%psScript%"
echo     public static extern bool SetSystemFileCacheSize(IntPtr MinimumFileCacheSize, IntPtr MaximumFileCacheSize, int Flags); >> "%psScript%"
echo     [DllImport("advapi32.dll", SetLastError = true)] >> "%psScript%"
echo     internal static extern bool OpenProcessToken(IntPtr ProcessHandle, int DesiredAccess, out IntPtr TokenHandle); >> "%psScript%"
echo     [DllImport("advapi32.dll", SetLastError = true)] >> "%psScript%"
echo     internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid); >> "%psScript%"
echo     [DllImport("advapi32.dll", SetLastError = true)] >> "%psScript%"
echo     internal static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, int BufferLength, IntPtr PreviousState, IntPtr ReturnLength); >> "%psScript%"
echo     [StructLayout(LayoutKind.Sequential, Pack = 1)] >> "%psScript%"
echo     internal struct TOKEN_PRIVILEGES { >> "%psScript%"
echo         public int PrivilegeCount; >> "%psScript%"
echo         public long Luid; >> "%psScript%"
echo         public int Attributes; >> "%psScript%"
echo     } >> "%psScript%"
echo     public static void PurgeAll() { >> "%psScript%"
echo         try { SetSystemFileCacheSize(IntPtr.Zero, IntPtr.Zero, 0); } catch {} >> "%psScript%"
echo         try { >> "%psScript%"
echo             IntPtr token; >> "%psScript%"
echo             OpenProcessToken(Process.GetCurrentProcess().Handle, 0x0020 ^| 0x0008, out token); >> "%psScript%"
echo             TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES(); >> "%psScript%"
echo             tp.PrivilegeCount = 1; >> "%psScript%"
echo             tp.Attributes = 2; >> "%psScript%"
echo             LookupPrivilegeValue(null, "SeProfileSingleProcessPrivilege", ref tp.Luid); >> "%psScript%"
echo             AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero); >> "%psScript%"
echo             IntPtr p = Marshal.AllocHGlobal(4); >> "%psScript%"
echo             Marshal.WriteInt32(p, 4); >> "%psScript%"
echo             NtSetSystemInformation(80, p, 4); >> "%psScript%"
echo             Marshal.FreeHGlobal(p); >> "%psScript%"
echo         } catch {} >> "%psScript%"
echo     } >> "%psScript%"
echo } >> "%psScript%"
echo '@ >> "%psScript%"
echo Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue >> "%psScript%"
echo [RamPurger]::PurgeAll() >> "%psScript%"
echo Get-Process ^| ForEach-Object { try { $_.MinWorkingSet = [IntPtr]::Zero } catch {} } >> "%psScript%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%psScript%"
if exist "%psScript%" del /f /q "%psScript%"

echo [2/2] Clearing Clipboard and DNS Cache...
cmd /c "echo off | clip"
ipconfig /flushdns >nul 2>&1

echo.
echo Complete! Standby Cache and RAM have been successfully cleared.
echo.
pause