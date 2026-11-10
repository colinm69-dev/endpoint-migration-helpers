function Get-SystemFact {
    <#
    .SYNOPSIS
        Collects the hardware facts used for the readiness check. Windows only.
    #>
    [CmdletBinding()]
    param()

    $facts = [ordered]@{
        TpmPresent        = $false
        TpmVersion        = ''
        UefiBoot          = $false
        SecureBootEnabled = $null
        RamGB             = 0
        SystemDiskGB      = 0
        CpuCores          = 0
        CpuClockMHz       = 0
        Cpu64Bit          = $false
        OsBuild           = 0
    }

    try {
        $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
        if ($tpm) {
            $facts.TpmPresent = $true
            $facts.TpmVersion = (([string]$tpm.SpecVersion -split ',')[0]).Trim()
        }
    }
    catch {
        Write-Verbose "TPM query failed: $($_.Exception.Message)"
    }

    try {
        $firmware = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction Stop
        $facts.UefiBoot = ($firmware.PEFirmwareType -eq 2)
    }
    catch {
        Write-Verbose "Firmware type query failed: $($_.Exception.Message)"
    }

    try {
        $facts.SecureBootEnabled = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
    }
    catch {
        Write-Verbose "Secure Boot query failed (normal on legacy BIOS): $($_.Exception.Message)"
    }

    try {
        $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $facts.RamGB = [math]::Round($system.TotalPhysicalMemory / 1GB, 1)

        $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
        $facts.SystemDiskGB = [math]::Round($drive.Size / 1GB, 1)

        $cpus = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)
        $facts.CpuCores = [int]($cpus | Measure-Object -Property NumberOfCores -Sum).Sum
        $facts.CpuClockMHz = [int]($cpus | Measure-Object -Property MaxClockSpeed -Maximum).Maximum
        $facts.Cpu64Bit = (@($cpus | Where-Object { $_.AddressWidth -eq 64 }).Count -gt 0)

        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $facts.OsBuild = [int]$os.BuildNumber
    }
    catch {
        Write-Verbose "Hardware query failed: $($_.Exception.Message)"
    }

    [PSCustomObject]$facts
}
