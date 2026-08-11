# AzureAD-LocalGroup-Adjustment

Interactive batch script that moves a specified Entra (Azure AD) user out of the local Administrators group and into the local Users group on a Windows machine.

## What it does

For the AzureAD user you enter, the script will:

1. **Add** the user to the local `Users` group.
2. **Remove** the user from the local `Administrators` group.

## Usage

1. Run the script (double-click or run from an elevated command prompt — local group changes require admin rights).
2. When prompted, enter the username only (e.g. `JohnDoe@domain`) — do **not** include the `AzureAD\` prefix, it's added automatically.
3. The script runs both commands and prints the output so you can confirm success.
4. Press any key to close.

```
Enter AzureAD username: JohnDoe@domain
```

## Behaviour notes

- If no username is entered, the script exits immediately and makes no changes.
- Commands run:
  ```
  net localgroup users "AzureAD\<username>" /add
  net localgroup administrators "AzureAD\<username>" /delete
  ```
- No confirmation prompt before applying — the two commands run as soon as a username is entered. Review the printed output afterward to confirm both completed without errors.
- **Self-deleting**: the script deletes itself (`%~f0`) after the pause, so it will not persist on disk after a run. Keep a master copy elsewhere if you need to reuse it.

## Requirements

- Must be run with local Administrator rights to modify local group membership.
- Machine must be Entra-joined (or hybrid-joined) with the `AzureAD\` local account prefix available.

## Use case

Quick remediation for AzureAD accounts that were granted local admin rights in error, downgrading them to standard local user without needing to open Computer Management manually.

## Caveats / possible improvements

- No validation that the entered username actually exists or is a valid AzureAD account before running the commands.
- No dry-run / preview mode — changes are applied immediately.
- No logging to file; output is only visible in the console window during the run.
