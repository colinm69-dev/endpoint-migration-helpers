# endpoint-migration-helpers

Generic, anonymised PowerShell helpers for planning and running a Windows endpoint migration to Microsoft Intune and Windows 11. Nothing here contains real tenant, device or user data; names in tests and examples are placeholders (`example.test`, `PC-0001`).

## What is in here

| Path | Purpose |
|---|---|
| `src/EndpointMigration/` | PowerShell module (5.1 and 7): inventory, Windows 11 readiness, enrolment check, Intune sync, user-state backup and restore, name anonymiser |
| `intune/remediations/` | Detection and remediation scripts for Intune Remediations (readiness, low disk, BitLocker report) |
| `intune/win32/` | Install, uninstall and detection templates for Win32 apps |
| `scripts/` | `Get-IntuneDeviceReport.ps1` (Graph, read-only) and `Export-MigrationInventory.ps1` |
| `tests/` | Pester 5 tests for the pure logic, with anonymised `dsregcmd` fixtures |
| `docs/runbook.md` | Suggested order of work for a migration |

## Quick start

```powershell
Import-Module .\src\EndpointMigration\EndpointMigration.psd1

Get-Win11Readiness
Get-IntuneEnrollmentStatus
Get-MigrationInventory -Anonymise -Salt 'a-private-salt' -Path .\inventory.json

# User state: always preview first
Backup-UserState -Destination D:\Backup -WhatIf
Backup-UserState -Destination D:\Backup -Hash
Restore-UserState -Source D:\Backup -Verify -WhatIf
```

## Design choices

- **Pure logic is separate from system calls.** Verdict and parsing functions take plain objects or text, so they are unit tested without a Windows device.
- **Safe by default.** Anything that changes state supports `-WhatIf`. Restore never overwrites newer files. Backup refuses a destination inside the source and refuses to exceed a size limit.
- **Anonymisation.** `Get-AnonymisedId` gives salted, stable identifiers so reports can be shared and compared. Keep the salt private; with the salt, names can be guessed and checked.
- **Backup contents are opt-in.** Browser bookmarks and settings are only included when asked for.

## What this does not do

- It does not check the CPU model against Microsoft's supported processor list. Readiness covers TPM 2.0, UEFI, Secure Boot, RAM, disk, cores, clock and 64-bit only.
- It does not enrol, join, wipe or reimage devices, and it does not enable BitLocker. Use Intune policies (Autopilot, endpoint security) for those.
- It does not back up application data, local databases, certificates or credentials. Back up the Documents, Desktop and similar folders only, plus optional bookmarks and printer and drive names.
- `Invoke-IntuneSync` is best effort: it starts the device's own Intune scheduled tasks, which is not an official, documented API.
- The scripts do not manage licences, and the Graph report does not change anything in your tenant.

## Testing status

Pure-logic functions have Pester tests that run in CI on Windows (`.github/workflows/ci.yml`). The functions that read real system state, run robocopy, call `dsregcmd`, or talk to Microsoft Graph and Intune were written against documented behaviour but have **not** been run against a real tenant or fleet by the author of this repository snapshot. Pilot on a few test devices first.

## Requirements

- Windows 10/11, Windows PowerShell 5.1 or PowerShell 7
- Admin rights for sync and some inventory items
- Graph report: `Microsoft.Graph.DeviceManagement` module and the `DeviceManagementManagedDevices.Read.All` permission
- Win32 packaging: Microsoft's Win32 Content Prep Tool (`IntuneWinAppUtil.exe`), which is not included

## Licence

MIT. See `LICENSE`.
