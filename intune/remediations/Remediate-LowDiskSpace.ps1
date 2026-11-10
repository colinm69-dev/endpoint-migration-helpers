<#
.SYNOPSIS
    Intune Remediations remediation script: removes old temporary files to free space.
.DESCRIPTION
    Deletes files older than $RetentionDays from the Windows temp folder and from each user's
    local temp folder. It touches nothing else (no Documents, no Downloads, no caches owned by
    other products). Supports -WhatIf for a dry run. Logs to ProgramData.
    Run as SYSTEM, 64-bit PowerShell.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$RetentionDays = 7
$LogFile = Join-Path -Path $env:ProgramData -ChildPath 'EndpointMigration\Logs\Remediate-LowDiskSpace.log'

function Write-Log {
    param([string]$Message)
    $dir = Split-Path -Parent $LogFile
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -LiteralPath $LogFile -Value ("{0} {1}" -f (Get-Date).ToString('s'), $Message)
}

$cutoff = (Get-Date).AddDays(-$RetentionDays)
$targets = @(Join-Path -Path $env:SystemRoot -ChildPath 'Temp')
$targets += @(Get-ChildItem -Path (Join-Path -Path $env:SystemDrive -ChildPath 'Users') -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path -Path $_.FullName -ChildPath 'AppData\Local\Temp' })

[long]$freed = 0
foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target)) { continue }
    $old = Get-ChildItem -LiteralPath $target -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
    foreach ($file in $old) {
        if ($PSCmdlet.ShouldProcess($file.FullName, 'Delete old temp file')) {
            try {
                $size = $file.Length
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $freed += $size
            }
            catch {
                Write-Log ("Skipped (in use or denied): {0}" -f $file.FullName)
            }
        }
    }
}

Write-Log ("Freed about {0} MB" -f [math]::Round($freed / 1MB, 1))
Write-Output ("FreedMB={0}" -f [math]::Round($freed / 1MB, 1))
exit 0
