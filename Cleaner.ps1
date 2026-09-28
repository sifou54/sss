#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "Windows Ultimate Safe Cleaner"

function Write-Status {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

function Get-FolderSizeMB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    if ($null -eq $size) { return 0 }
    return [math]::Round($size / 1MB, 2)
}

function Clean-Path {
    param(
        [string]$Path,
        [string]$Description,
        [int]$DaysOld = 0,
        [switch]$RemoveEmptyOnly
    )
    
    if (-not (Test-Path $Path)) {
        Write-Status "  -> Path not found: $Path" "DarkGray"
        return 0
    }

    $before = Get-FolderSizeMB -Path $Path
    Write-Status "  -> Cleaning: $Description  |  Before: $before MB"

    try {
        if ($RemoveEmptyOnly) {
            Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -eq 0 } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        elseif ($DaysOld -gt 0) {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysOld) } |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        else {
            Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    catch {}

    Get-ChildItem -Path $Path -Recurse -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0 } |
        Sort-Object { $_.FullName.Length } -Descending |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    $after = Get-FolderSizeMB -Path $Path
    $freed = [math]::Round($before - $after, 2)
    if ($freed -gt 0) {
        Write-Status "  -> Freed: $freed MB" "Green"
    }
    return $freed
}

function Stop-ServiceSafe {
    param([string]$ServiceName)
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        return $true
    }
    return $false
}

function Start-ServiceSafe {
    param([string]$ServiceName)
    Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
}

Clear-Host
Write-Host "Windows Ultimate Safe Cleaner - Starting..." -ForegroundColor Magenta
Write-Host ""

$totalFreed = 0.0

Write-Status "======= 1. Temp Folders =======" "Yellow"
$totalFreed += Clean-Path -Path $env:TEMP -Description "User TEMP"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Temp" -Description "LocalAppData\Temp"
$totalFreed += Clean-Path -Path "C:\Windows\Temp" -Description "Windows\Temp"
$totalFreed += Clean-Path -Path "C:\Temp" -Description "C:\Temp"
$totalFreed += Clean-Path -Path "C:\Windows\Logs\CBS" -Description "CBS Logs" -DaysOld 7

Write-Status "======= 2. Prefetch =======" "Yellow"
$totalFreed += Clean-Path -Path "C:\Windows\Prefetch" -Description "Prefetch" -DaysOld 5

Write-Status "======= 3. Recycle Bin =======" "Yellow"
try {
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.NameSpace(0xA)
    $recycleBin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Status "  -> Recycle Bin emptied" "Green"
} catch {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Status "  -> Recycle Bin emptied" "Green"
}

Write-Status "======= 4. Windows Update & Delivery Optimization =======" "Yellow"
$wuStopped = Stop-ServiceSafe -ServiceName "wuauserv"
$bitsStopped = Stop-ServiceSafe -ServiceName "bits"
$doStopped = Stop-ServiceSafe -ServiceName "DoSvc"

$totalFreed += Clean-Path -Path "C:\Windows\SoftwareDistribution\Download" -Description "WU Download"
$totalFreed += Clean-Path -Path "C:\Windows\SoftwareDistribution\DeliveryOptimization" -Description "Delivery Optimization"
$totalFreed += Clean-Path -Path "C:\Windows\SoftwareDistribution\DataStore" -Description "WU DataStore" -DaysOld 14
$totalFreed += Clean-Path -Path "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization\Cache" -Description "DO Cache"

if ($wuStopped) { Start-ServiceSafe -ServiceName "wuauserv" }
if ($bitsStopped) { Start-ServiceSafe -ServiceName "bits" }
if ($doStopped) { Start-ServiceSafe -ServiceName "DoSvc" }

Write-Status "======= 5. Thumbnail / Icon / Font Cache =======" "Yellow"
$thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
Get-ChildItem -Path $thumbPath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
Write-Status "  -> Thumbnail Cache deleted" "Green"

$iconCache = "$env:LOCALAPPDATA\IconCache.db"
if (Test-Path $iconCache) {
    Remove-Item $iconCache -Force -ErrorAction SilentlyContinue
    Write-Status "  -> IconCache.db deleted" "Green"
}

$fontStopped = Stop-ServiceSafe -ServiceName "FontCache"
$totalFreed += Clean-Path -Path "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache" -Description "Font Cache"
if ($fontStopped) { Start-ServiceSafe -ServiceName "FontCache" }

Write-Status "======= 6. DNS / ARP / NetBIOS =======" "Yellow"
Clear-DnsClientCache
arp -d *
nbtstat -R
nbtstat -RR
Write-Status "  -> DNS + ARP + NetBIOS cleared" "Green"

Write-Status "======= 7. Error Reporting + Crash Dumps =======" "Yellow"
$totalFreed += Clean-Path -Path "C:\ProgramData\Microsoft\Windows\WER" -Description "WER" -DaysOld 5
$totalFreed += Clean-Path -Path "C:\Windows\Minidump" -Description "Minidump" -DaysOld 14
$totalFreed += Clean-Path -Path "C:\Windows\LiveKernelReports" -Description "LiveKernelReports" -DaysOld 14
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\CrashDumps" -Description "CrashDumps" -DaysOld 7

Write-Status "======= 8. DirectX + GPU Shader Cache =======" "Yellow"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\D3DSCache" -Description "DirectX Shader Cache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\NVIDIA\DXCache" -Description "NVIDIA DXCache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\NVIDIA\GLCache" -Description "NVIDIA GLCache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\AMD\DxCache" -Description "AMD DxCache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\AMD\GLCache" -Description "AMD GLCache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Intel\ShaderCache" -Description "Intel ShaderCache"

Write-Status "======= 9. Browser Caches =======" "Yellow"

$chromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\ShaderCache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker\CacheStorage"
)
foreach ($p in $chromePaths) { $totalFreed += Clean-Path -Path $p -Description "Chrome Cache" }

$edgePaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\ShaderCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage"
)
foreach ($p in $edgePaths) { $totalFreed += Clean-Path -Path $p -Description "Edge Cache" }

$ffProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
foreach ($profile in $ffProfiles) {
    $totalFreed += Clean-Path -Path "$($profile.FullName)\cache2" -Description "Firefox cache2"
    $totalFreed += Clean-Path -Path "$($profile.FullName)\startupCache" -Description "Firefox startupCache"
    $totalFreed += Clean-Path -Path "$($profile.FullName)\thumbnails" -Description "Firefox thumbnails"
}

$operaPaths = @(
    "$env:APPDATA\Opera Software\Opera Stable\Cache",
    "$env:APPDATA\Opera Software\Opera Stable\GPUCache",
    "$env:APPDATA\Opera Software\Opera Stable\Code Cache"
)
foreach ($p in $operaPaths) { $totalFreed += Clean-Path -Path $p -Description "Opera Cache" }

$bravePaths = @(
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\GPUCache"
)
foreach ($p in $bravePaths) { $totalFreed += Clean-Path -Path $p -Description "Brave Cache" }

Write-Status "======= 10. Microsoft Office Cache =======" "Yellow"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache" -Description "Office File Cache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Microsoft\Office\15.0\OfficeFileCache" -Description "Office 15 File Cache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Microsoft\Windows\OfficeFileCache" -Description "OfficeFileCache"

Write-Status "======= 11. Windows Store + App Cache =======" "Yellow"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Microsoft\Windows\AppCache" -Description "AppCache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" -Description "INetCache"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Microsoft\Windows\WebCache" -Description "WebCache"

Write-Status "======= 12. Recent Items + Jump Lists =======" "Yellow"
$totalFreed += Clean-Path -Path "$env:APPDATA\Microsoft\Windows\Recent" -Description "Recent Items"
$totalFreed += Clean-Path -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations" -Description "Jump Lists"
$totalFreed += Clean-Path -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations" -Description "Custom Destinations"

Write-Status "======= 13. Windows Logs =======" "Yellow"
$totalFreed += Clean-Path -Path "C:\Windows\Logs" -Description "Windows Logs" -DaysOld 14
$totalFreed += Clean-Path -Path "C:\Windows\System32\LogFiles" -Description "System32 LogFiles" -DaysOld 14
$totalFreed += Clean-Path -Path "C:\Windows\Panther" -Description "Panther Logs" -DaysOld 30

Write-Status "======= 14. BranchCache + DO Extra =======" "Yellow"
$totalFreed += Clean-Path -Path "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\PeerDistRepub" -Description "BranchCache"
$totalFreed += Clean-Path -Path "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization" -Description "DO NetworkService"

Write-Status "======= 15. Empty Files =======" "Yellow"
$emptyTargets = @(
    $env:TEMP,
    "$env:LOCALAPPDATA\Temp",
    "C:\Windows\Temp",
    "C:\Windows\Logs",
    "C:\Windows\SoftwareDistribution"
)
foreach ($t in $emptyTargets) {
    $totalFreed += Clean-Path -Path $t -Description "Empty files" -RemoveEmptyOnly
}

Write-Status "======= 16. Event Logs =======" "Yellow"
wevtutil el | ForEach-Object {
    wevtutil cl "$_" 2>$null
}
Write-Status "  -> Event Logs cleared" "Green"

Write-Status "======= 17. Extra Safe Locations =======" "Yellow"
$totalFreed += Clean-Path -Path "C:\Windows\Downloaded Program Files" -Description "Downloaded Program Files"
$totalFreed += Clean-Path -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Description "Explorer Cache" -DaysOld 7

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Cleaning completed successfully" -ForegroundColor Green
Write-Host "Total space freed (approx): $([math]::Round($totalFreed, 2)) MB" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Please restart your computer now." -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")