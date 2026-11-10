# Migration runbook (outline)

A suggested order of work. Adapt it to your environment and test on a pilot group first.

1. **Assess.** Run `Get-MigrationInventory -Anonymise -Salt ...` on a sample, or deploy `Detect-Win11Readiness.ps1` as an Intune Remediation (detection only) and read the report. Group devices by verdict: Ready, ReadyAfterChange, NotReady.
2. **Plan fixes.** ReadyAfterChange is usually Secure Boot or firmware settings. NotReady means hardware replacement; the CPU model still needs checking against Microsoft's supported list, which these scripts do not do.
3. **Prepare.** Confirm free disk space (`Detect-LowDiskSpace.ps1`), pending reboots, and BitLocker state (`Detect-BitLocker.ps1`, report only). Check Microsoft's documentation for the licensing Remediations require in your tenant.
4. **Back up user state** where the migration needs it: `Backup-UserState -Destination <share or disk> -Hash`. Preview with `-WhatIf`. Keep the manifest with the backup.
5. **Enrol.** Use your normal route (Autopilot, hybrid join, or user-driven enrolment). `Get-IntuneEnrollmentStatus` shows the join type and MDM state before and after.
6. **Verify.** Run `Get-IntuneEnrollmentStatus`, then `Invoke-IntuneSync` if a device is slow to pick up policy. Check compliance in the admin centre or with `Get-IntuneDeviceReport.ps1`.
7. **Restore** where needed: `Restore-UserState -Source <backup> -Verify -WhatIf`, then without `-WhatIf`. Newer files on the device are never replaced.
8. **Rollback.** Keep the backup until the user confirms. The scripts do not undo an enrolment; plan the rollback route (retire, wipe, reimage) with your own process.
