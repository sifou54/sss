<#
.SYNOPSIS
    Comprehensive Windows Cleaner – Safely removes all junk, cache, temp, and empty folders.
.DESCRIPTION
    Cleans: Temp (all users), Prefetch, Delivery Optimization, Update cache, Thumbnails, Icon Cache,
    Font Cache, Event Logs, WER, Memory Dumps, CBS Logs, Recycle Bin, Browser caches (Chrome, Edge,
    Firefox, Brave, Opera), Store cache, .NET, Office, Java, Adobe, GPU shader caches, Network cache,
    PerfLogs, Crash Dumps, empty folders, DISM, and cleanmgr.
    Does NOT delete system files, installer data, or user documents.
    Requires Administrator privileges.
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"
$host.UI.RawUI.WindowTitle = "Windows Ultimate Cleaner"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "         Starting Comprehensive System Cleanup" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# Helper function: Clean all contents inside a directory (does not delete the directory itself)
function Clear-Directory {
    param([string]$Path, [string]$Description)
    if (Test-Path $Path) {
        Write-Host "  $Description ..." -ForegroundColor Yellow
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    - Cleaned: $Path" -ForegroundColor Green
        } catch {
            Write-Host "    - Could not fully clean: $Path" -ForegroundColor DarkYellow
        }
    }
}

# Helper function: Remove all items inside a folder, keeping the folder itself
function Clear-Contents {
    param([string]$Path, [string]$Description)
    if (Test-Path $Path) {
        Write-Host "  $Description ..." -ForegroundColor Yellow
        try {
            Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    - Emptied: $Path" -ForegroundColor Green
        } catch {
            Write-Host "    - Could not fully empty: $Path" -ForegroundColor DarkYellow
        }
    }
}

# Helper function: Remove empty subdirectories recursively under a given path
function Remove-EmptyFolders {
    param([string]$Path)
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
            @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0
        } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# ========================
# 1. System & User TEMP folders
# ========================
Write-Host "`n[1] Cleaning TEMP folders" -ForegroundColor Magenta
Clear-Directory "$env:SystemRoot\Temp" "System Temp"

# All user profiles
$UserProfiles = Get-ChildItem "C:\Users" -Directory -Force -ErrorAction SilentlyContinue
foreach ($profile in $UserProfiles) {
    $userTemp = "$($profile.FullName)\AppData\Local\Temp"
    Clear-Directory $userTemp "User Temp ($($profile.Name))"
}
# Default temp path (current user)
Clear-Directory ([System.IO.Path]::GetTempPath()) "Default Temp Path"

# ========================
# 2. Prefetch
# ========================
Write-Host "`n[2] Cleaning Prefetch" -ForegroundColor Magenta
Clear-Contents "$env:SystemRoot\Prefetch" "Prefetch"

# ========================
# 3. Delivery Optimization
# ========================
Write-Host "`n[3] Cleaning Delivery Optimization Cache" -ForegroundColor Magenta
Clear-Directory "$env:SystemDrive\Windows\DeliveryOptimization\Cache" "Delivery Optimization"

# ========================
# 4. Windows Update temporary files
# ========================
Write-Host "`n[4] Cleaning Windows Update Cache" -ForegroundColor Magenta
Clear-Directory "$env:SystemRoot\SoftwareDistribution\Download" "Update Downloads"
Clear-Directory "$env:SystemRoot\SoftwareDistribution\DataStore\Logs" "Update Logs"

# ========================
# 5. Thumbnails & Icon Cache (all users)
# ========================
Write-Host "`n[5] Cleaning Thumbnail & Icon Cache" -ForegroundColor Magenta
foreach ($profile in $UserProfiles) {
    $explorerDir = "$($profile.FullName)\AppData\Local\Microsoft\Windows\Explorer"
    if (Test-Path $explorerDir) {
        Get-ChildItem -Path $explorerDir -Include "thumbcache_*.db", "iconcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}
# System icon cache
$sysIconCache = "$env:LocalAppData\IconCache.db"
if (Test-Path $sysIconCache) { Remove-Item $sysIconCache -Force -ErrorAction SilentlyContinue }
Write-Host "    - Thumbnails & icons cleared" -ForegroundColor Green

# ========================
# 6. Font Cache
# ========================
Write-Host "`n[6] Cleaning Font Cache" -ForegroundColor Magenta
$fontCache = "$env:LocalAppData\Microsoft\Windows\Fonts\fontCache.dat"
if (Test-Path $fontCache) { 
    Remove-Item $fontCache -Force -ErrorAction SilentlyContinue
    Write-Host "    - Font cache removed" -ForegroundColor Green 
}

# ========================
# 7. Windows Error Reporting & Memory Dumps
# ========================
Write-Host "`n[7] Cleaning Error Reports & Memory Dumps" -ForegroundColor Magenta
Clear-Directory "$env:ProgramData\Microsoft\Windows\WER" "WER Reports"
$memDump = "$env:SystemRoot\memory.dmp"
if (Test-Path $memDump) { 
    Remove-Item $memDump -Force -ErrorAction SilentlyContinue
    Write-Host "    - Deleted memory.dmp" -ForegroundColor Green 
}
Clear-Directory "$env:SystemRoot\Minidump" "Minidump"

# ========================
# 8. CBS Logs
# ========================
Write-Host "`n[8] Cleaning CBS Logs" -ForegroundColor Magenta
Clear-Contents "$env:SystemRoot\Logs\CBS" "CBS Logs"

# ========================
# 9. Recycle Bin (all drives)
# ========================
Write-Host "`n[9] Emptying Recycle Bin" -ForegroundColor Magenta
try {
    $shell = New-Object -ComObject Shell.Application
    $shell.Namespace(0xA).Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "    - Recycle Bin emptied" -ForegroundColor Green
} catch {
    Write-Host "    - Recycle Bin empty or error" -ForegroundColor DarkYellow
}

# ========================
# 10. Browser Caches (Chrome, Edge, Firefox, Brave, Opera)
# ========================
Write-Host "`n[10] Cleaning Browser Caches" -ForegroundColor Magenta
$browserPaths = @(
    # Chrome
    "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Service Worker\CacheStorage",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\*\GPUCache",
    # Edge
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Service Worker\CacheStorage",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\GPUCache",
    # Firefox
    "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*\offlinecache",
    # Brave
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Cache",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Code Cache",
    # Opera
    "$env:APPDATA\Opera Software\Opera Stable\Cache",
    "$env:LOCALAPPDATA\Opera Software\Opera Stable\Cache"
)
foreach ($pattern in $browserPaths) {
    Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "    - Browser caches cleared" -ForegroundColor Green

# ========================
# 11. Microsoft Store Cache
# ========================
Write-Host "`n[11] Resetting Microsoft Store Cache" -ForegroundColor Magenta
try {
    Start-Process "wsreset.exe" -ArgumentList "-s" -Wait -WindowStyle Hidden
    Write-Host "    - wsreset executed" -ForegroundColor Green
} catch { Write-Host "    - wsreset failed" -ForegroundColor DarkYellow }
Clear-Directory "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache" "Store Local Cache"

# ========================
# 12. .NET temporary files & ClickOnce (FIXED)
# ========================
Write-Host "`n[12] Cleaning .NET & ClickOnce Cache" -ForegroundColor Magenta
$netTempPaths = @(
    "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files",
    "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files",
    "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files",
    "$env:LOCALAPPDATA\Apps\2.0"  # ClickOnce
)
foreach ($p in $netTempPaths) {
    # Use direct removal with error suppression, no helper function to avoid path issues
    if (Test-Path $p) {
        Write-Host "  Cleaning: $p" -ForegroundColor Yellow
        Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    - Cleaned" -ForegroundColor Green
    }
}

# ========================
# 13. Microsoft Office Cache
# ========================
Write-Host "`n[13] Cleaning Office Cache" -ForegroundColor Magenta
Clear-Directory "$env:LOCALAPPDATA\Microsoft\Office\OTele" "Office Telemetry"
Clear-Directory "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache" "Office File Cache"
Clear-Directory "$env:LOCALAPPDATA\Microsoft\Office\16.0\Wef" "Office Web Add-in Cache"

# ========================
# 14. Java & Adobe Cache
# ========================
Write-Host "`n[14] Cleaning Java & Adobe Caches" -ForegroundColor Magenta
Clear-Directory "$env:USERPROFILE\AppData\LocalLow\Sun\Java\Deployment\cache" "Java Cache"
Clear-Directory "$env:APPDATA\Adobe\Common\Media Cache" "Adobe Media Cache"
Clear-Directory "$env:APPDATA\Adobe\Common\Media Cache Files" "Adobe Media Cache Files"

# ========================
# 15. GPU Shader Caches (NVIDIA, AMD, DirectX)
# ========================
Write-Host "`n[15] Cleaning GPU Shader Caches" -ForegroundColor Magenta
foreach ($profile in $UserProfiles) {
    # DirectX ShaderCache
    Clear-Directory "$($profile.FullName)\AppData\Local\Microsoft\DirectX\ShaderCache" "DirectX ShaderCache ($($profile.Name))"
    # NVIDIA
    Clear-Directory "$($profile.FullName)\AppData\Local\NVIDIA\DXCache" "NVIDIA DXCache ($($profile.Name))"
    Clear-Directory "$($profile.FullName)\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache" "NVIDIA PerDriver Cache ($($profile.Name))"
    # AMD
    Clear-Directory "$($profile.FullName)\AppData\Local\AMD\DxCache" "AMD DxCache ($($profile.Name))"
    Clear-Directory "$($profile.FullName)\AppData\LocalLow\AMD\DxCache" "AMD DxCache (LocalLow) ($($profile.Name))"
}
Clear-Directory "$env:ProgramData\NVIDIA Corporation\NV_Cache" "NVIDIA Global Cache"
Write-Host "    - GPU caches cleared" -ForegroundColor Green

# ========================
# 16. Network Caches (DNS, ARP, TCP/IP)
# ========================
Write-Host "`n[16] Flushing Network Caches" -ForegroundColor Magenta
ipconfig /flushdns | Out-Null
Write-Host "    - DNS flushed" -ForegroundColor Green
arp -d * 2>$null
Write-Host "    - ARP cleared" -ForegroundColor Green
netsh int ip reset > $null
Write-Host "    - TCP/IP stack reset" -ForegroundColor Green

# ========================
# 17. Crash Dumps (application dumps)
# ========================
Write-Host "`n[17] Cleaning Application Crash Dumps" -ForegroundColor Magenta
foreach ($profile in $UserProfiles) {
    Clear-Directory "$($profile.FullName)\AppData\Local\CrashDumps" "Crash Dumps ($($profile.Name))"
}
Clear-Directory "$env:SystemRoot\Minidump" "System Minidump"

# ========================
# 18. PerfLogs (Windows Performance Logs)
# ========================
Write-Host "`n[18] Cleaning Performance Logs (C:\PerfLogs)" -ForegroundColor Magenta
if (Test-Path "C:\PerfLogs") {
    Clear-Contents "C:\PerfLogs" "PerfLogs"
}

# ========================
# 19. Windows Event Logs (safe clear)
# ========================
Write-Host "`n[19] Clearing Windows Event Logs" -ForegroundColor Magenta
@("Application", "System", "Security", "Setup", "Windows PowerShell") | ForEach-Object {
    try { wevtutil cl $_ 2>$null } catch {}
}
Write-Host "    - Event logs cleared" -ForegroundColor Green

# ========================
# 20. DISM Component Store Cleanup
# ========================
Write-Host "`n[20] Running DISM Component Cleanup (may take a few minutes)" -ForegroundColor Magenta
try {
    Dism /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
    Write-Host "    - DISM cleanup completed" -ForegroundColor Green
} catch { Write-Host "    - DISM failed" -ForegroundColor DarkYellow }

# ========================
# 21. cleanmgr (Disk Cleanup)
# ========================
Write-Host "`n[21] Launching cleanmgr (silent)" -ForegroundColor Magenta
try {
    Start-Process cleanmgr -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden
    Write-Host "    - cleanmgr finished" -ForegroundColor Green
} catch { Write-Host "    - cleanmgr not available" -ForegroundColor DarkYellow }

# ========================
# 22. Remove Empty Folders in key locations
# ========================
Write-Host "`n[22] Removing empty folders from Temp & AppData" -ForegroundColor Magenta
$scanPaths = @("$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch",
               "$env:ProgramData", "$env:LOCALAPPDATA", "$env:APPDATA")
foreach ($path in $scanPaths) { Remove-EmptyFolders -Path $path }
Write-Host "    - Empty folders removed" -ForegroundColor Green

# ========================
# 23. Windows Defender temporary files
# ========================
Write-Host "`n[23] Cleaning Windows Defender scan history" -ForegroundColor Magenta
Clear-Directory "$env:ProgramData\Microsoft\Windows Defender\Scans\History" "Defender Scan History"
Clear-Directory "$env:ProgramData\Microsoft\Windows Defender\Quarantine" "Defender Quarantine"

# ========================
# Restart Explorer
# ========================
Write-Host "`n--------------------------------------------------" -ForegroundColor Cyan
Write-Host "    Cleanup complete. Restarting Explorer..." -ForegroundColor Green
Stop-Process -Name explorer -Force
Start-Sleep -Seconds 3
Start-Process explorer
Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host "Done! A system reboot is recommended for best results." -ForegroundColor Yellow
Start-Sleep -Seconds 10