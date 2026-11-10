<#
.SYNOPSIS
    Template detection script for an Intune Win32 app (custom script detection rule).
.DESCRIPTION
    Intune treats "exit code 0 plus any output on stdout" as detected. Edit the settings block.
#>
[CmdletBinding()]
param()

# ---- Settings: edit these ---------------------------------------------------------------
$AppDisplayName = 'ExampleApp'
$MinimumVersion = [version]'1.0.0'
# ------------------------------------------------------------------------------------------

$paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$entry = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq $AppDisplayName } |
    Select-Object -First 1

if ($entry -and $entry.DisplayVersion) {
    $installed = $null
    if ([version]::TryParse([string]$entry.DisplayVersion, [ref]$installed) -and $installed -ge $MinimumVersion) {
        Write-Output ("Detected {0} {1}" -f $AppDisplayName, $installed)
        exit 0
    }
}
exit 1
