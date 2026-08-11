# Clear-WallpaperPolicy-AllProfiles

Removes a locked wallpaper/lock-screen policy from **every local user profile** on a Windows machine — not just the currently logged-in user.

## What it removes

| Value | Location |
|---|---|
| `Wallpaper` | `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System` |
| `WallpaperStyle` | `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System` |

These are removed from each user's own hive on the machine — local accounts, Entra (Azure AD) accounts, logged-on or not.

## How it works

1. Enumerates all local profile SIDs from `ProfileList`, covering both on-prem/local accounts (`S-1-5-21-...`) and Entra/Azure AD accounts (`S-1-12-1-...`).
2. For profiles that are already loaded (logged-on users), works directly against their `HKEY_USERS` hive.
3. For profiles not currently loaded, temporarily mounts their offline `NTUSER.DAT` via `reg.exe load`, applies the change, then unmounts (`reg.exe unload`), with a garbage-collect and short delay first to avoid file-lock failures.
4. Deletes only the two values above — no ownership or ACL changes. A GPO-locked value fails the delete cleanly and is logged, rather than halting the run.
5. Finishes with a belt-and-braces pass against the caller's own live `HKCU` hive.

## Usage

```powershell
# Preview only — no changes made (default)
.\Clear-WallpaperPolicy-AllProfiles.ps1

# Apply the changes
.\Clear-WallpaperPolicy-AllProfiles.ps1 -DryRun:$false
```

> **Note:** The script defaults to `-DryRun $true`. You must explicitly pass `-DryRun:$false` to apply changes.

## Requirements

- Must run elevated (Administrator). The script performs a real elevation check at runtime rather than relying solely on `#Requires -RunAsAdministrator`, since that directive doesn't fire when dot-sourced or run via RMM.
- Designed to be SYSTEM-context safe for RMM deployment.

## Logging

Every run writes a UTF-8 (no BOM) log to:

```
C:\Source\NetPrimates-Logs\Clear-WallpaperPolicy-AllProfiles_<yyyyMMdd_HHmmss>.log
```

Log entries include which values were removed (or would be removed in dry-run mode), any profiles skipped, and any failures (e.g. GPO-locked values).

## Use case

Remediation for machines where a previously-applied wallpaper/lock-screen enforcement policy needs stripping across **all** users on a shared or multi-user device.

## Conventions

Ordered `$Config` hashtable, `$DryRun` defaults to `$true`, UTF-8 no-BOM logging via .NET `StreamWriter`.
