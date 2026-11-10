<#
.SYNOPSIS
    Template uninstall script for an Intune Win32 app. Copy it, then edit the settings block.
.DESCRIPTION
    Looks up the uninstall string in the registry by display name and runs it silently.
    Uninstall command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-App.ps1
#>
[CmdletBinding()]
param()

# ---- Settings: edit these ---------------------------------------------------------------
$AppDisplayName = 'ExampleApp'               # exact DisplayName shown in Apps and Features
$SilentArguments = '/S'                      # check the vendor's documented silent switch
# ------------------------------------------------------------------------------------------

$paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$entry = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq $AppDisplayName -and $_.UninstallString } |
    Select-Object -First 1

if (-not $entry) {
    Write-Output "$AppDisplayName is not installed."
    exit 0
}

$command = $entry.UninstallString.Trim('"')
$process = Start-Process -FilePath $command -ArgumentList $SilentArguments -Wait -PassThru -NoNewWindow
exit $process.ExitCode
