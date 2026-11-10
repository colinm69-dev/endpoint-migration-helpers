function Get-MigrationInventory {
    <#
    .SYNOPSIS
        Collects a migration-readiness snapshot of this device.
    .DESCRIPTION
        Returns operating system, Windows 11 readiness, BitLocker status, join and MDM status,
        pending reboot state and, optionally, installed applications. Use -Anonymise with -Salt to
        replace the computer name with a stable identifier before sharing results.
    .PARAMETER Anonymise
        Replace the computer name with a salted identifier.
    .PARAMETER Salt
        Private salt used with -Anonymise.
    .PARAMETER IncludeApplication
        Also list installed applications (names and versions).
    .PARAMETER Path
        Write the result to this JSON file as well as returning it.
    .EXAMPLE
        Get-MigrationInventory -Anonymise -Salt 'my-private-salt' -Path .\device.json
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Anonymise,
        [string]$Salt,
        [switch]$IncludeApplication,
        [string]$Path
    )

    $computerName = $env:COMPUTERNAME
    if ($Anonymise) {
        if (-not $Salt) {
            throw '-Salt is required with -Anonymise so identifiers stay the same between runs.'
        }
        $computerName = Get-AnonymisedId -Value $computerName -Salt $Salt -Prefix 'dev'
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop

    $bitlocker = [PSCustomObject]@{ Protected = $null; Status = 'Unknown'; Method = '' }
    try {
        $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        $bitlocker = [PSCustomObject]@{
            Protected = ($volume.ProtectionStatus.ToString() -eq 'On')
            Status    = $volume.VolumeStatus.ToString()
            Method    = $volume.EncryptionMethod.ToString()
        }
    }
    catch {
        Write-Verbose "BitLocker query failed (needs elevation): $($_.Exception.Message)"
    }

    $enrolment = $null
    try {
        $enrolment = Get-IntuneEnrollmentStatus
    }
    catch {
        Write-Verbose "Enrolment query failed: $($_.Exception.Message)"
    }

    $result = [ordered]@{
        ComputerName   = $computerName
        CollectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        OperatingSystem = [PSCustomObject]@{
            Caption  = $os.Caption
            Version  = $os.Version
            Family   = (ConvertFrom-OsVersion -OsVersion $os.Version).Family
            LastBoot = $os.LastBootUpTime.ToUniversalTime().ToString('o')
        }
        SystemDriveFreeGB = [math]::Round($drive.FreeSpace / 1GB, 1)
        Windows11Readiness = (Get-Win11Readiness | Select-Object -Property Verdict, AlreadyWindows11, Blockers, Fixable)
        BitLocker      = $bitlocker
        Enrolment      = $enrolment
        PendingReboot  = (Test-PendingReboot)
    }
    if ($IncludeApplication) {
        $result['Applications'] = @(Get-InstalledApplication)
    }

    $inventory = [PSCustomObject]$result

    if ($Path -and $PSCmdlet.ShouldProcess($Path, 'Write inventory JSON')) {
        $inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    $inventory
}
