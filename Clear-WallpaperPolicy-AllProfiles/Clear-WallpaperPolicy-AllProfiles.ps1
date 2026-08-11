#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NP-RemoveWallpaperPolicyAllUsers.ps1
    Deletes HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Wallpaper and
    WallpaperStyle for every local user profile on the machine. Straight delete only —
    no ownership/ACL modification. If a key is GPO-locked, the delete will fail and get logged.

.DESCRIPTION
    Sweeps all local profiles (logged-on live hives and offline NTUSER.DAT files, mounted temporarily)
    and removes the two values from each.

.NOTES
    Convention: NP-prefix, ordered $Config, $DryRun default true, UTF-8 no-BOM logging via
    .NET StreamWriter, SYSTEM-context safe for Asio RMM deployment.
#>

[CmdletBinding()]
param(
    [switch]$DryRun = $false
)

$Config = [ordered]@{
    LogDir      = 'C:\Source\NetPrimates-Logs'
    LogFile     = "NP-RemoveWallpaperPolicyAllUsers_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
    RelativeKey = 'Software\Microsoft\Windows\CurrentVersion\Policies\System'
    ValueNames  = @('Wallpaper', 'WallpaperStyle')
}

$null = New-Item -Path $Config.LogDir -ItemType Directory -Force -ErrorAction SilentlyContinue
$logPath = Join-Path $Config.LogDir $Config.LogFile
$writer  = [System.IO.StreamWriter]::new($logPath, $true, [System.Text.UTF8Encoding]::new($false))

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $writer.WriteLine($line)
    $writer.Flush()
    Write-Host $line
}

# Real elevation check — #Requires -RunAsAdministrator only fires when invoked as a .ps1 file
$currentIdentity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
$isElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated -and -not $DryRun) {
    $msg = "Not running elevated (identity: $($currentIdentity.Name)). Re-launch PowerShell as Administrator, or run this as a .ps1 file via RMM/SYSTEM context."
    Write-Log $msg 'ERROR'
    $writer.Close()
    throw $msg
}

function Remove-RegValueIfExists {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path $Path)) { return }
    $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $prop) { return }

    if ($DryRun) {
        Write-Log "[DRYRUN] Would remove value '$Name' at $Path"
        return
    }
    try {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
        Write-Log "Removed value '$Name' at $Path"
    } catch {
        Write-Log "FAILED to remove value '$Name' at '$Path': $($_.Exception.Message)" 'ERROR'
    }
}

function Get-AllUserHiveRoots {
    # Returns a PS-path-style root ('Registry::HKEY_USERS\SID') for every local profile SID,
    # mounting offline NTUSER.DAT files as needed.
    $results = @()
    $sids = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty PSChildName

    foreach ($sid in $sids) {
        # S-1-5-21-... = local/on-prem domain accounts. S-1-12-1-... = Entra (Azure AD) accounts.
        # Both are real user profiles and need covering — the old S-1-5-21-only filter silently
        # skipped Azure AD users entirely.
        if ($sid -notmatch '^(S-1-5-21-|S-1-12-1-)' -or $sid -match '_Classes$') { continue }

        $loadedPath = "Registry::HKEY_USERS\$sid"
        if (Test-Path $loadedPath) {
            $results += [pscustomobject]@{ SID = $sid; Root = $loadedPath; Mounted = $false }
            continue
        }

        $profilePath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -ErrorAction SilentlyContinue).ProfileImagePath
        if (-not $profilePath) { continue }
        $ntUserDat = Join-Path $profilePath 'NTUSER.DAT'

        $exists = $false
        try { $exists = Test-Path -LiteralPath $ntUserDat -ErrorAction Stop }
        catch { Write-Log "Skipping profile $sid ($profilePath) — cannot access NTUSER.DAT: $($_.Exception.Message)" 'WARN' }
        if (-not $exists) { continue }

        if ($DryRun) {
            Write-Log "[DRYRUN] Would mount hive for $sid ($profilePath)"
            $results += [pscustomobject]@{ SID = $sid; Root = $loadedPath; Mounted = $false; Simulated = $true }
            continue
        }
        try {
            & reg.exe load "HKU\$sid" "$ntUserDat" | Out-Null
            $results += [pscustomobject]@{ SID = $sid; Root = $loadedPath; Mounted = $true }
        } catch {
            Write-Log "FAILED to mount hive for $sid : $($_.Exception.Message)" 'ERROR'
        }
    }
    return $results
}

Write-Log "=== NP-RemoveWallpaperPolicyAllUsers starting (DryRun=$DryRun) ==="

$hives = Get-AllUserHiveRoots
foreach ($hive in $hives) {
    $keyPath = Join-Path $hive.Root $Config.RelativeKey
    foreach ($name in $Config.ValueNames) {
        Remove-RegValueIfExists -Path $keyPath -Name $name
    }
    if ($hive.Mounted -and -not $DryRun) {
        [gc]::Collect()
        Start-Sleep -Milliseconds 500
        & reg.exe unload "HKU\$($hive.SID)" | Out-Null
        Write-Log "Unmounted hive for $($hive.SID)"
    }
}

# Caller's own live HKCU (belt-and-braces on top of the HKEY_USERS sweep above)
$callerKeyPath = "HKCU:\$($Config.RelativeKey)"
foreach ($name in $Config.ValueNames) {
    Remove-RegValueIfExists -Path $callerKeyPath -Name $name
}

Write-Log "=== Complete. DryRun=$DryRun. Re-run with -DryRun:`$false to apply. Log: $logPath ==="
$writer.Close()