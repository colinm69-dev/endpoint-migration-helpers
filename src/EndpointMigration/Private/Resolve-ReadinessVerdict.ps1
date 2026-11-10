function Resolve-ReadinessVerdict {
    <#
    .SYNOPSIS
        Turns hardware facts into a Windows 11 readiness verdict. Pure logic, no system calls.
    .DESCRIPTION
        Verdicts:
          Ready            - every check passes.
          ReadyAfterChange - only fixable items fail (for example Secure Boot is off on a UEFI device).
          NotReady         - at least one hard requirement fails.
        The CPU model is NOT checked against Microsoft's supported processor list.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Facts
    )

    $checks = New-Object System.Collections.Generic.List[object]

    function Add-Check {
        param($Name, $Required, $Actual, [bool]$Passed, $Severity, $Remediation)
        $checks.Add([PSCustomObject]@{
                Name        = $Name
                Required    = $Required
                Actual      = $Actual
                Passed      = $Passed
                Severity    = $Severity
                Remediation = $Remediation
            })
    }

    $tpmOk = [bool]$Facts.TpmPresent -and ([string]$Facts.TpmVersion).StartsWith('2')
    $tpmActual = if ($Facts.TpmPresent) { "TPM $($Facts.TpmVersion)" } else { 'No TPM found' }
    Add-Check -Name 'TPM 2.0' -Required 'TPM 2.0' -Actual $tpmActual -Passed $tpmOk -Severity 'Blocker' -Remediation 'Enable the TPM or firmware TPM (fTPM/PTT) in firmware settings.'

    $uefiActual = if ($Facts.UefiBoot) { 'UEFI' } else { 'Legacy BIOS' }
    Add-Check -Name 'UEFI boot' -Required 'UEFI' -Actual $uefiActual -Passed ([bool]$Facts.UefiBoot) -Severity 'Blocker' -Remediation 'Convert the disk to GPT (MBR2GPT) and switch firmware to UEFI.'

    $secureOk = [bool]$Facts.UefiBoot -and ($Facts.SecureBootEnabled -eq $true)
    $secureActual = if ($Facts.SecureBootEnabled -eq $true) { 'Enabled' } elseif ($Facts.SecureBootEnabled -eq $false) { 'Disabled' } else { 'Unavailable' }
    $secureSeverity = if ($Facts.UefiBoot) { 'Fixable' } else { 'Blocker' }
    Add-Check -Name 'Secure Boot' -Required 'Enabled' -Actual $secureActual -Passed $secureOk -Severity $secureSeverity -Remediation 'Enable Secure Boot in firmware settings.'

    Add-Check -Name 'Memory' -Required '4 GB or more' -Actual ('{0} GB' -f $Facts.RamGB) -Passed ([double]$Facts.RamGB -ge 4) -Severity 'Blocker' -Remediation 'Upgrade memory.'
    Add-Check -Name 'System drive size' -Required '64 GB or more' -Actual ('{0} GB' -f $Facts.SystemDiskGB) -Passed ([double]$Facts.SystemDiskGB -ge 64) -Severity 'Blocker' -Remediation 'Replace or expand the system disk.'
    Add-Check -Name 'CPU cores' -Required '2 or more' -Actual ('{0}' -f $Facts.CpuCores) -Passed ([int]$Facts.CpuCores -ge 2) -Severity 'Blocker' -Remediation 'Replace the device.'
    Add-Check -Name 'CPU clock' -Required '1 GHz or faster' -Actual ('{0} MHz' -f $Facts.CpuClockMHz) -Passed ([int]$Facts.CpuClockMHz -ge 1000) -Severity 'Blocker' -Remediation 'Replace the device.'
    Add-Check -Name '64-bit CPU' -Required '64-bit' -Actual ($(if ($Facts.Cpu64Bit) { '64-bit' } else { '32-bit' })) -Passed ([bool]$Facts.Cpu64Bit) -Severity 'Blocker' -Remediation 'Replace the device.'

    $failed = @($checks | Where-Object { -not $_.Passed })
    $blockers = @($failed | Where-Object { $_.Severity -eq 'Blocker' })

    $verdict = 'Ready'
    if ($blockers.Count -gt 0) {
        $verdict = 'NotReady'
    }
    elseif ($failed.Count -gt 0) {
        $verdict = 'ReadyAfterChange'
    }

    [PSCustomObject]@{
        Verdict          = $verdict
        AlreadyWindows11 = ([int]$Facts.OsBuild -ge 22000)
        Checks           = $checks.ToArray()
        Blockers         = @($blockers | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Actual })
        Fixable          = @($failed | Where-Object { $_.Severity -eq 'Fixable' } | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Remediation })
        Notes            = @('CPU model was not checked against the Microsoft supported processor list.')
        Facts            = $Facts
    }
}
