<#
.SYNOPSIS
    Read-only report of Intune-managed Windows devices, with a Windows 11 / Windows 10 split.
.DESCRIPTION
    Uses the Microsoft Graph PowerShell SDK with the read-only permission
    DeviceManagementManagedDevices.Read.All. It changes nothing in the tenant. Device names,
    users and serial numbers are not exported; with -Anonymise the device name is replaced by a
    salted identifier so the CSV can be shared.
    Prerequisite: Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
.PARAMETER OutputPath
    CSV file to write.
.PARAMETER Anonymise
    Replace device names with salted identifiers (requires -Salt).
.PARAMETER Salt
    Private salt for -Anonymise.
.EXAMPLE
    .\Get-IntuneDeviceReport.ps1 -OutputPath .\devices.csv -Anonymise -Salt 'my-private-salt'
#>
[CmdletBinding()]
param(
    [string]$OutputPath = '.\intune-device-report.csv',
    [switch]$Anonymise,
    [string]$Salt
)

if ($Anonymise -and -not $Salt) {
    throw '-Salt is required with -Anonymise.'
}

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\src\EndpointMigration\EndpointMigration.psd1') -Force
Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop

Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

$devices = Get-MgDeviceManagementManagedDevice -All -Filter "operatingSystem eq 'Windows'"

$rows = foreach ($device in $devices) {
    $info = ConvertFrom-OsVersion -OsVersion ([string]$device.OsVersion)
    $name = [string]$device.DeviceName
    if ($Anonymise) {
        $name = Get-AnonymisedId -Value $name -Salt $Salt -Prefix 'dev'
    }
    [PSCustomObject]@{
        Device          = $name
        OsFamily        = $info.Family
        OsVersion       = $device.OsVersion
        ComplianceState = $device.ComplianceState
        Manufacturer    = $device.Manufacturer
        Model           = $device.Model
        EnrolledUtc     = $device.EnrolledDateTime
        LastSyncUtc     = $device.LastSyncDateTime
    }
}

$rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
Write-Output ('Wrote {0} device(s) to {1}' -f @($rows).Count, $OutputPath)
$rows | Group-Object -Property OsFamily | Select-Object -Property Name, Count | Format-Table -AutoSize | Out-String | Write-Output

Disconnect-MgGraph | Out-Null
