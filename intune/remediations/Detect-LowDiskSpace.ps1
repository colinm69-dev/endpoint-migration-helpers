<#
.SYNOPSIS
    Intune Remediations detection script: flags devices with low free space on the system drive.
.DESCRIPTION
    Exits 1 (issue found, remediation runs) when free space is below the threshold.
    Edit $ThresholdGB to suit your environment. Run as SYSTEM, 64-bit PowerShell.
#>
[CmdletBinding()]
param()

$ThresholdGB = 20

try {
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
    Write-Output ("FreeGB={0};ThresholdGB={1}" -f $freeGB, $ThresholdGB)
    if ($freeGB -lt $ThresholdGB) { exit 1 } else { exit 0 }
}
catch {
    Write-Output ("Error: {0}" -f $_.Exception.Message)
    exit 1
}
