<#
.SYNOPSIS
    Runs the migration inventory on this device and writes JSON, ready for use in an Intune
    platform script or by hand.
.EXAMPLE
    .\Export-MigrationInventory.ps1 -OutputFolder C:\ProgramData\EndpointMigration -Anonymise -Salt 'my-private-salt'
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Join-Path -Path $env:ProgramData -ChildPath 'EndpointMigration'),
    [switch]$Anonymise,
    [string]$Salt,
    [switch]$IncludeApplication
)

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '..\src\EndpointMigration\EndpointMigration.psd1') -Force

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}
$file = Join-Path -Path $OutputFolder -ChildPath ('inventory-{0}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))

$arguments = @{ Path = $file; IncludeApplication = $IncludeApplication }
if ($Anonymise) { $arguments['Anonymise'] = $true; $arguments['Salt'] = $Salt }
$null = Get-MigrationInventory @arguments
Write-Output "Wrote $file"
