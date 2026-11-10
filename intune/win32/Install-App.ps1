<#
.SYNOPSIS
    Template install script for an Intune Win32 app. Copy it, then edit the settings block.
.DESCRIPTION
    Runs a silent installer, logs the result and maps common "success, reboot needed" exit codes
    to 0 so Intune treats them as success. The installer file is placeholder text: nothing real
    is bundled here.
    Install command: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-App.ps1
#>
[CmdletBinding()]
param()

# ---- Settings: edit these ---------------------------------------------------------------
$AppName = 'ExampleApp'
$InstallerFile = 'ExampleAppSetup.exe'      # file packaged next to this script
$SilentArguments = '/S'                      # check the vendor's documented silent switch
$SuccessExitCodes = @(0, 3010)               # 3010 = success, reboot required
# ------------------------------------------------------------------------------------------

$logDir = Join-Path -Path $env:ProgramData -ChildPath 'EndpointMigration\Logs'
$logFile = Join-Path -Path $logDir -ChildPath ("Install-{0}.log" -f $AppName)
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $logFile -Value ("{0} {1}" -f (Get-Date).ToString('s'), $Message)
}

$installer = Join-Path -Path $PSScriptRoot -ChildPath $InstallerFile
if (-not (Test-Path -LiteralPath $installer)) {
    Write-Log "Installer not found: $installer"
    exit 1
}

Write-Log "Starting install of $AppName"
$process = Start-Process -FilePath $installer -ArgumentList $SilentArguments -Wait -PassThru -NoNewWindow
Write-Log ("Installer exit code: {0}" -f $process.ExitCode)

if ($SuccessExitCodes -contains $process.ExitCode) {
    exit 0
}
exit $process.ExitCode
