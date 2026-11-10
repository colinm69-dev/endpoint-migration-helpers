<#
.SYNOPSIS
    Intune Remediations detection script: reports Windows 11 hardware readiness.
.DESCRIPTION
    Standalone (Intune runs one script file). Prints a single compact JSON line that appears in
    the Remediations report, then exits 0 when the device is Ready and 1 otherwise.
    There is no remediation script: hardware problems cannot be fixed by a script. Use the output
    to plan replacements or firmware changes.
    The CPU model is not checked against Microsoft's supported processor list.
    Run as SYSTEM, 64-bit PowerShell.
#>
[CmdletBinding()]
param()

$result = [ordered]@{ Verdict = 'Unknown'; Failed = @() }

try {
    $failed = New-Object System.Collections.Generic.List[string]
    $hardFail = $false

    $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    if (-not $tpm -or -not ([string]$tpm.SpecVersion).StartsWith('2')) { $failed.Add('TPM2'); $hardFail = $true }

    $uefi = $false
    $fw = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction SilentlyContinue
    if ($fw -and $fw.PEFirmwareType -eq 2) { $uefi = $true }
    if (-not $uefi) { $failed.Add('UEFI'); $hardFail = $true }

    $secureBoot = $false
    try { $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $secureBoot = $false }
    if (-not $secureBoot) { $failed.Add('SecureBoot') }

    $ram = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($ram -lt 4) { $failed.Add('RAM'); $hardFail = $true }

    $disk = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'").Size / 1GB
    if ($disk -lt 64) { $failed.Add('Disk'); $hardFail = $true }

    $cpus = @(Get-CimInstance -ClassName Win32_Processor)
    $cores = ($cpus | Measure-Object -Property NumberOfCores -Sum).Sum
    $clock = ($cpus | Measure-Object -Property MaxClockSpeed -Maximum).Maximum
    $is64 = (@($cpus | Where-Object { $_.AddressWidth -eq 64 }).Count -gt 0)
    if ($cores -lt 2 -or $clock -lt 1000 -or -not $is64) { $failed.Add('CPU'); $hardFail = $true }

    $verdict = 'Ready'
    if ($hardFail) { $verdict = 'NotReady' }
    elseif ($failed.Count -gt 0) { $verdict = 'ReadyAfterChange' }

    $result.Verdict = $verdict
    $result.Failed = $failed.ToArray()
}
catch {
    $result.Verdict = 'Error'
    $result.Failed = @($_.Exception.Message)
}

# Intune shows up to about 2 KB of output, so keep it short.
Write-Output ($result | ConvertTo-Json -Compress)
if ($result.Verdict -eq 'Ready') { exit 0 } else { exit 1 }
