function Restore-UserState {
    <#
    .SYNOPSIS
        Copies a backup made by Backup-UserState into a user profile.
    .DESCRIPTION
        Reads manifest.json from the backup folder and copies each folder back with robocopy,
        skipping any file that is older than the copy already in the profile (it never replaces a
        newer file). With -Verify it first checks every file against the SHA256 hashes recorded by
        Backup-UserState -Hash and stops if anything does not match.
    .PARAMETER Source
        The folder that was used as -Destination when the backup was made.
    .PARAMETER ProfilePath
        The profile to restore into. Defaults to the current user's profile.
    .PARAMETER Folder
        Restore only these folders. Defaults to everything in the manifest.
    .PARAMETER Verify
        Check the backup against its recorded hashes before restoring.
    .EXAMPLE
        Restore-UserState -Source 'E:\Backups\user01' -Verify -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [string]$ProfilePath = $env:USERPROFILE,

        [string[]]$Folder,

        [switch]$Verify,

        [string]$LogPath
    )

    $allowed = @('Desktop', 'Documents', 'Pictures', 'Downloads', 'Music', 'Videos')
    $manifestPath = Join-Path -Path $Source -ChildPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "No manifest.json found in $Source. Is this a Backup-UserState backup?"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.SchemaVersion -ne 1) {
        throw "Unsupported manifest version: $($manifest.SchemaVersion)"
    }

    $names = @($manifest.Folders | ForEach-Object { $_.Name })
    if ($Folder) {
        $names = @($names | Where-Object { $Folder -contains $_ })
    }
    foreach ($name in $names) {
        if ($allowed -notcontains $name) {
            throw "Refusing to restore unexpected folder name from manifest: $name"
        }
    }

    $stateRoot = Join-Path -Path $Source -ChildPath 'UserState'

    if ($Verify) {
        $files = @($manifest.Files)
        if ($files.Count -eq 0) {
            throw 'The manifest has no file hashes. Make the backup with -Hash to use -Verify.'
        }
        $bad = @()
        foreach ($entry in $files) {
            $full = Join-Path -Path $stateRoot -ChildPath $entry.Path
            if (-not (Test-Path -LiteralPath $full)) { $bad += "Missing: $($entry.Path)"; continue }
            $actual = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
            if ($actual -ne $entry.Sha256) { $bad += "Changed: $($entry.Path)" }
        }
        if ($bad.Count -gt 0) {
            throw ('Backup verification failed for {0} file(s). First problem: {1}' -f $bad.Count, $bad[0])
        }
        Write-MigrationLog -Message ('Verified {0} file(s).' -f $files.Count) -LogPath $LogPath
    }

    $restored = 0
    foreach ($name in $names) {
        $from = Join-Path -Path $stateRoot -ChildPath $name
        $to = Join-Path -Path $ProfilePath -ChildPath $name
        if (-not (Test-Path -LiteralPath $from)) {
            Write-MigrationLog -Message "Backup folder missing, skipped: $name" -Level Warning -LogPath $LogPath
            continue
        }
        if ($PSCmdlet.ShouldProcess($to, "Restore $name from backup")) {
            $code = Invoke-RobocopyCopy -Source $from -Destination $to -ExtraOption @('/XO') -LogFile (Join-Path -Path $Source -ChildPath 'restore.log')
            if (-not (Test-RobocopyExitCode -ExitCode $code)) {
                throw "robocopy failed for $name with exit code $code."
            }
            $restored++
        }
    }
    Write-MigrationLog -Message "Restore finished. Folders restored: $restored" -LogPath $LogPath
    $restored
}
