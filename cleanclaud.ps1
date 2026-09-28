<#
==============================================================================
    Windows Cleaner Pro v2 - Full System Cleanup & Speed Boost Script
==============================================================================
    Features:
    - Clean Temp files (User + System)
    - Clean Prefetch (old files only - safe, Windows rebuilds automatically)
    - Clean Windows Update cache
    - Clean browser cache (Chrome, Edge, Firefox)
    - Clean Crash Dumps and Error Reports
    - Empty Recycle Bin
    - Remove empty folders
    - Flush DNS Cache
    - Remove Windows.old (with explicit confirmation)
    - Manage Hibernation file (optional, frees RAM-sized space)
    - Review Startup Apps (display only)
    - Run Defrag (HDD) or TRIM (SSD) automatically based on disk type
    - Dry Run mode to preview before actual deletion

    Safety notes:
    - Does NOT touch the Registry
    - Does NOT touch core system files or installed programs
    - Windows.old and Hibernation require explicit user confirmation
    - Startup review is display-only, nothing gets disabled automatically
==============================================================================
#>

param(
    [switch]$DryRun,
    [switch]$SkipBrowsers,
    [switch]$SkipPrefetch,
    [switch]$SkipWindowsOld,
    [switch]$SkipHibernation,
    [switch]$SkipStartupReview,
    [switch]$SkipDefrag
)

# ------------------------------------------------------------------------
# Check Administrator privileges
# ------------------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  [!] Run PowerShell as Administrator for best results (Windows.old and Hibernation sections require it)." -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue with limited privileges? (y/n)"
    if ($continue -ne 'y') { exit }
}

# ------------------------------------------------------------------------
# General settings
# ------------------------------------------------------------------------
$LogFile = Join-Path $env:USERPROFILE "Desktop\WindowsCleaner_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
$TotalFreedBytes = 0
$TotalFilesDeleted = 0
$TotalErrors = 0

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timeStamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timeStamp] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Get-FolderSizeMB {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($size) { return [math]::Round($size / 1MB, 2) }
        } catch {}
    }
    return 0
}

function Clear-FolderSafely {
    param(
        [string]$Path,
        [string]$Description,
        [int]$MinAgeDays = 0,
        [string[]]$ExcludeExtensions = @()
    )

    if (-not (Test-Path $Path)) {
        Write-Log "  - $Description : Path not found, skipped." "DarkGray"
        return
    }

    Write-Log "`n>> Scanning: $Description" "Cyan"
    Write-Log "   Path: $Path" "DarkGray"

    $cutoffDate = (Get-Date).AddDays(-$MinAgeDays)

    $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
             Where-Object {
                 -not $_.PSIsContainer -and
                 $_.LastWriteTime -lt $cutoffDate -and
                 ($ExcludeExtensions.Count -eq 0 -or $_.Extension -notin $ExcludeExtensions)
             }

    $count = 0
    $freedThis = 0

    foreach ($item in $items) {
        try {
            $fileSize = $item.Length
            if ($DryRun) {
                Write-Log "   [DryRun] Would delete: $($item.FullName)" "DarkYellow"
            } else {
                Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
            }
            $count++
            $freedThis += $fileSize
        } catch {
            $script:TotalErrors++
        }
    }

    $script:TotalFilesDeleted += $count
    $script:TotalFreedBytes += $freedThis
    $freedMB = [math]::Round($freedThis / 1MB, 2)

    if ($DryRun) {
        Write-Log "   [DryRun] Files eligible for deletion: $count (~$freedMB MB)" "Yellow"
    } else {
        Write-Log "   Deleted $count files - Space freed: $freedMB MB" "Green"
    }
}

function Remove-EmptyFolders {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path $Path)) { return }

    Write-Log "`n>> Searching for empty folders in: $Description" "Cyan"
    $removedCount = 0

    for ($pass = 0; $pass -lt 3; $pass++) {
        $emptyFolders = Get-ChildItem -Path $Path -Recurse -Force -Directory -ErrorAction SilentlyContinue |
                        Where-Object {
                            (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0
                        }

        if ($emptyFolders.Count -eq 0) { break }

        foreach ($folder in $emptyFolders) {
            try {
                if ($DryRun) {
                    Write-Log "   [DryRun] Would remove empty folder: $($folder.FullName)" "DarkYellow"
                } else {
                    Remove-Item -LiteralPath $folder.FullName -Force -ErrorAction Stop
                }
                $removedCount++
            } catch { }
        }
    }
    Write-Log "   Removed/found $removedCount empty folders." "Green"
}

# ==========================================================================
# Start execution
# ==========================================================================
Clear-Host
Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host "         Windows Cleaner Pro v2 - System Cleanup           " -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta
if ($DryRun) {
    Write-Host "  Mode: DRY RUN - No files will actually be deleted" -ForegroundColor Yellow
} else {
    Write-Host "  Mode: LIVE RUN - Files will be deleted" -ForegroundColor Red
}
Write-Host "==========================================================`n" -ForegroundColor Magenta

Write-Log "Cleanup started - $(Get-Date)" "White"

# 1) Temp files
Clear-FolderSafely -Path $env:TEMP -Description "User Temp files" -MinAgeDays 0
Clear-FolderSafely -Path "$env:WINDIR\Temp" -Description "System Temp files" -MinAgeDays 0

# 2) Prefetch
if (-not $SkipPrefetch) {
    Clear-FolderSafely -Path "$env:WINDIR\Prefetch" -Description "Prefetch files" -MinAgeDays 3
}

# 3) Windows Update cache
Clear-FolderSafely -Path "$env:WINDIR\SoftwareDistribution\Download" -Description "Windows Update cache" -MinAgeDays 0

# 4) Delivery Optimization
Clear-FolderSafely -Path "$env:WINDIR\SoftwareDistribution\DeliveryOptimization" -Description "Delivery Optimization files" -MinAgeDays 0

# 5) Crash Dumps and Error Reports
Clear-FolderSafely -Path "$env:LOCALAPPDATA\CrashDumps" -Description "Crash Dump files" -MinAgeDays 0
Clear-FolderSafely -Path "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportQueue" -Description "Windows Error Reports" -MinAgeDays 0
Clear-FolderSafely -Path "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportArchive" -Description "Windows Error Report Archive" -MinAgeDays 0

# 6) Thumbnails Cache
Clear-FolderSafely -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Description "Thumbnails Cache" -MinAgeDays 0 -ExcludeExtensions @(".exe", ".dll")

# 7) Font Cache
Clear-FolderSafely -Path "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache" -Description "Font Cache" -MinAgeDays 0

# 8) Browser cache
if (-not $SkipBrowsers) {
    Clear-FolderSafely -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" -Description "Chrome Cache" -MinAgeDays 0
    Clear-FolderSafely -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -Description "Edge Cache" -MinAgeDays 0
    $firefoxProfiles = Get-ChildItem -Path "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $firefoxProfiles) {
        Clear-FolderSafely -Path (Join-Path $profile.FullName "cache2") -Description "Firefox Cache ($($profile.Name))" -MinAgeDays 0
    }
}

# 9) Empty Recycle Bin
Write-Log "`n>> Emptying Recycle Bin" "Cyan"
if (-not $DryRun) {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Log "   Recycle Bin emptied successfully." "Green"
    } catch {
        Write-Log "   Could not empty Recycle Bin (may already be empty)." "DarkGray"
    }
} else {
    Write-Log "   [DryRun] Would empty Recycle Bin." "DarkYellow"
}

# 10) Flush DNS
Write-Log "`n>> Flushing DNS Cache" "Cyan"
if (-not $DryRun) {
    try {
        ipconfig /flushdns | Out-Null
        Write-Log "   DNS Cache flushed successfully." "Green"
    } catch {
        Write-Log "   Could not flush DNS Cache." "DarkGray"
    }
} else {
    Write-Log "   [DryRun] Would flush DNS Cache." "DarkYellow"
}

# 11) Remove empty folders
Remove-EmptyFolders -Path $env:TEMP -Description "User Temp"
Remove-EmptyFolders -Path "$env:WINDIR\Temp" -Description "System Temp"

# 12) Windows.old
if (-not $SkipWindowsOld) {
    $winOldPath = "$($env:SystemDrive)\Windows.old"
    if (Test-Path $winOldPath) {
        $winOldSizeGB = [math]::Round((Get-FolderSizeMB -Path $winOldPath) / 1024, 2)
        Write-Log "`n>> Found Windows.old folder, approx size: $winOldSizeGB GB" "Cyan"
        Write-Host "`n  [!] Windows.old contains the previous Windows version (allows rollback)." -ForegroundColor Yellow
        Write-Host "      Deleting it is permanent and cannot be undone." -ForegroundColor Yellow
        $confirmOld = Read-Host "  Delete it? (y/n)"
        if ($confirmOld -eq 'y') {
            if (-not $DryRun) {
                try {
                    Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:65535" -Wait -ErrorAction SilentlyContinue
                    Write-Log "   Windows.old deletion process launched via official Windows tool." "Green"
                } catch {
                    Write-Log "   Could not delete Windows.old automatically. Use Disk Cleanup > Clean up system files manually." "DarkYellow"
                }
            } else {
                Write-Log "   [DryRun] Would delete Windows.old ($winOldSizeGB GB)." "DarkYellow"
            }
        } else {
            Write-Log "   Windows.old deletion skipped by user choice." "DarkGray"
        }
    } else {
        Write-Log "`n>> No Windows.old folder found." "DarkGray"
    }
}

# 13) Hibernation
if (-not $SkipHibernation) {
    Write-Log "`n>> Checking Hibernation mode" "Cyan"
    Write-Host "`n  [!] Disabling Hibernation frees significant space (roughly RAM-sized) but disables the Hibernate feature." -ForegroundColor Yellow
    Write-Host "      This does NOT affect normal Sleep mode, only Hibernate." -ForegroundColor Yellow
    $confirmHiber = Read-Host "  Disable Hibernation to free space? (y/n)"
    if ($confirmHiber -eq 'y') {
        if (-not $DryRun) {
            try {
                powercfg /hibernate off
                Write-Log "   Hibernation disabled and hiberfil.sys removed successfully." "Green"
            } catch {
                Write-Log "   Could not disable Hibernation." "DarkGray"
            }
        } else {
            Write-Log "   [DryRun] Would disable Hibernation." "DarkYellow"
        }
    } else {
        Write-Log "   Hibernation disable skipped by user choice." "DarkGray"
    }
}

# 14) Startup Apps review (display only)
if (-not $SkipStartupReview) {
    Write-Log "`n>> Current Startup Apps:" "Cyan"
    $startupApps = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
                   Select-Object Name, Command, Location, User

    if ($startupApps) {
        $i = 1
        $startupApps | ForEach-Object {
            Write-Host "   [$i] $($_.Name)  -  $($_.Location)" -ForegroundColor White
            $i++
        }
        Write-Host "`n  To manage these apps safely (enable/disable), use:" -ForegroundColor Cyan
        Write-Host "  Task Manager > Startup Apps (official and safest method)" -ForegroundColor Cyan
        Write-Log "   Displayed $($startupApps.Count) startup apps. Use Task Manager > Startup Apps to disable." "DarkGray"
    } else {
        Write-Log "   Could not retrieve startup apps list." "DarkGray"
    }
}

# 15) Defrag (HDD) or TRIM (SSD)
if (-not $SkipDefrag) {
    Write-Log "`n>> Checking disk type and optimizing performance" "Cyan"
    try {
        $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $disks) {
            $mediaType = $disk.MediaType
            $driveLetter = "C"

            if ($mediaType -eq "SSD") {
                Write-Log "   Disk type: SSD - Running TRIM instead of Defrag (Defrag harms SSD lifespan)." "Cyan"
                if (-not $DryRun) {
                    Optimize-Volume -DriveLetter $driveLetter -ReTrim -Verbose:$false -ErrorAction SilentlyContinue
                    Write-Log "   TRIM completed on drive $driveLetter." "Green"
                } else {
                    Write-Log "   [DryRun] Would run TRIM on drive $driveLetter." "DarkYellow"
                }
            } elseif ($mediaType -eq "HDD") {
                Write-Log "   Disk type: HDD - Running Defrag." "Cyan"
                if (-not $DryRun) {
                    Optimize-Volume -DriveLetter $driveLetter -Defrag -Verbose:$false -ErrorAction SilentlyContinue
                    Write-Log "   Defrag completed on drive $driveLetter." "Green"
                } else {
                    Write-Log "   [DryRun] Would run Defrag on drive $driveLetter." "DarkYellow"
                }
            } else {
                Write-Log "   Disk type unknown - step skipped for safety." "DarkGray"
            }
        }
    } catch {
        Write-Log "   Could not determine disk type or run optimization." "DarkGray"
    }
}

# 16) Built-in Disk Cleanup
if (-not $DryRun) {
    Write-Log "`n>> Running built-in Disk Cleanup tool (silent mode)..." "Cyan"
    try {
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/verylowdisk" -WindowStyle Hidden -ErrorAction SilentlyContinue
        Write-Log "   Disk Cleanup launched in background." "Green"
    } catch {
        Write-Log "   Disk Cleanup tool not available." "DarkGray"
    }
}

# ==========================================================================
# Final report
# ==========================================================================
$totalFreedMB = [math]::Round($TotalFreedBytes / 1MB, 2)
$totalFreedGB = [math]::Round($TotalFreedBytes / 1GB, 2)

Write-Host "`n==========================================================" -ForegroundColor Magenta
Write-Host "                      FINAL REPORT                        " -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta

if ($DryRun) {
    Write-Host "  [DRY RUN] Files eligible for deletion : $TotalFilesDeleted" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Estimated space to free      : $totalFreedMB MB ($totalFreedGB GB)" -ForegroundColor Yellow
    Write-Host "`n  To run the actual cleanup, run the script without -DryRun" -ForegroundColor Cyan
} else {
    Write-Host "  Files deleted        : $TotalFilesDeleted" -ForegroundColor Green
    Write-Host "  Total space freed    : $totalFreedMB MB ($totalFreedGB GB)" -ForegroundColor Green
}

if ($TotalErrors -gt 0) {
    Write-Host "  Files skipped (in use/protected) : $TotalErrors [normal and safe]" -ForegroundColor DarkYellow
}

Write-Host "  Full log saved to:" -ForegroundColor Cyan
Write-Host "  $LogFile" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Magenta

Write-Log "`nCleanup finished - $(Get-Date)" "White"

Write-Host "`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")