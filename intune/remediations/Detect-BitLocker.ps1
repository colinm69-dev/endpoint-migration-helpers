<#
.SYNOPSIS
    Intune Remediations detection script: reports whether the system drive is BitLocker protected.
.DESCRIPTION
    Detection only. Exits 1 when protection is off. There is deliberately no remediation script:
    enabling BitLocker and escrowing recovery keys should be done with an Intune endpoint security
    (disk encryption) policy, not an ad hoc script.
    Run as SYSTEM, 64-bit PowerShell.
#>
[CmdletBinding()]
param()

try {
    $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    $status = $volume.ProtectionStatus.ToString()
    Write-Output ("Protection={0};Method={1}" -f $status, $volume.EncryptionMethod)
    if ($status -eq 'On') { exit 0 } else { exit 1 }
}
catch {
    Write-Output ("Error: {0}" -f $_.Exception.Message)
    exit 1
}
