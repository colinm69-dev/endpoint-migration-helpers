function Backup-UserState {
    <#
    .SYNOPSIS
        Copies a user's key folders to a backup location before a device migration.
    .DESCRIPTION
        Uses robocopy to copy the chosen known folders (default Desktop, Documents, Pictures) and
        writes a manifest.json. Safeguards: it refuses to run if the destination is inside a source
        folder, refuses if the data is larger than -MaxSizeGB, and supports -WhatIf. It does not
        copy credentials, and it only exports printer and drive-mapping names if you ask for them.
        The manifest and settings can contain file, server and printer names, so treat the backup
        as sensitive.
    .PARAMETER Destination
        Folder to write the backup to (for example a network share or an external drive).
    .PARAMETER Folder
        Which profile folders to copy.
    .PARAMETER ProfilePath
        The user profile to read from. Defaults to the current user's profile.
    .PARAMETER MaxSizeGB
        Stop if the selected folders add up to more than this many gigabytes.
    .PARAMETER IncludeBrowserBookmark
        Also copy the Chrome and Edge bookmark files.
    .PARAMETER IncludeSettings
        Also export printer names and mapped drive paths to settings.json.
    .PARAMETER Hash
        Record a SHA256 hash for every file, so Restore-UserState -Verify can check the backup.
    .PARAMETER LogPath
        Optional log file.
    .EXAMPLE
        Backup-UserState -Destination 'E:\Backups\user01' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$Destination,

        [ValidateSet('Desktop', 'Documents', 'Pictures', 'Downloads', 'Music', 'Videos')]
        [string[]]$Folder = @('Desktop', 'Documents', 'Pictures'),

        [string]$ProfilePath = $env:USERPROFILE,

        [ValidateRange(1, 4096)]
        [int]$MaxSizeGB = 20,

        [switch]$IncludeBrowserBookmark,
        [switch]$IncludeSettings,
        [switch]$Hash,
        [string]$LogPath
    )

    if (-not $ProfilePath -or -not (Test-Path -LiteralPath $ProfilePath -PathType Container)) {
        throw "Profile path not found: $ProfilePath"
    }

    $selected = New-Object System.Collections.Generic.List[object]
    [long]$totalBytes = 0
    foreach ($name in $Folder) {
        $source = Join-Path -Path $ProfilePath -ChildPath $name
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            Write-MigrationLog -Message "Skipping missing folder: $name" -Level Warning -LogPath $LogPath
            continue
        }
        if (Test-PathInside -Parent $source -Child $Destination) {
            throw "The destination is inside the folder being backed up ($name). Choose a different destination."
        }
        $bytes = Get-FolderSizeBytes -Path $source
        $selected.Add([PSCustomObject]@{ Name = $name; Source = $source; Bytes = $bytes })
        $totalBytes += $bytes
    }

    if ($selected.Count -eq 0) {
        throw 'None of the requested folders exist, so there is nothing to back up.'
    }
    $limitBytes = [long]$MaxSizeGB * 1GB
    if ($totalBytes -gt $limitBytes) {
        throw ('Selected folders total {0} GB, above the {1} GB limit. Raise -MaxSizeGB if this is intended.' -f [math]::Round($totalBytes / 1GB, 1), $MaxSizeGB)
    }

    Write-MigrationLog -Message ('Backing up {0} folder(s), {1} GB' -f $selected.Count, [math]::Round($totalBytes / 1GB, 2)) -LogPath $LogPath

    $stateRoot = Join-Path -Path $Destination -ChildPath 'UserState'
    $robocopyLog = Join-Path -Path $Destination -ChildPath 'robocopy.log'
    $folderResults = New-Object System.Collections.Generic.List[object]

    foreach ($item in $selected) {
        $target = Join-Path -Path $stateRoot -ChildPath $item.Name
        if ($PSCmdlet.ShouldProcess($item.Name, "Copy to $target")) {
            if (-not (Test-Path -LiteralPath $target)) {
                New-Item -ItemType Directory -Path $target -Force | Out-Null
            }
            $code = Invoke-RobocopyCopy -Source $item.Source -Destination $target -LogFile $robocopyLog
            if (-not (Test-RobocopyExitCode -ExitCode $code)) {
                throw "robocopy failed for $($item.Name) with exit code $code. See $robocopyLog."
            }
            $folderResults.Add([PSCustomObject]@{ Name = $item.Name; Bytes = $item.Bytes; RobocopyExitCode = $code })
        }
    }

    if ($IncludeBrowserBookmark -and $PSCmdlet.ShouldProcess('Browser bookmarks', 'Copy')) {
        $bookmarkSources = @{
            Chrome = (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Google\Chrome\User Data\Default\Bookmarks')
            Edge   = (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Edge\User Data\Default\Bookmarks')
        }
        foreach ($browser in $bookmarkSources.Keys) {
            if (Test-Path -LiteralPath $bookmarkSources[$browser]) {
                $bookmarkDir = Join-Path -Path $stateRoot -ChildPath 'Bookmarks'
                New-Item -ItemType Directory -Path $bookmarkDir -Force | Out-Null
                Copy-Item -LiteralPath $bookmarkSources[$browser] -Destination (Join-Path -Path $bookmarkDir -ChildPath "$browser-Bookmarks.json")
            }
        }
    }

    if ($IncludeSettings -and $PSCmdlet.ShouldProcess('Printer and drive mappings', 'Export names')) {
        $settings = [PSCustomObject]@{
            Printers     = @(Get-Printer -ErrorAction SilentlyContinue | Select-Object -Property Name, DriverName)
            MappedDrives = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.DisplayRoot } | Select-Object -Property Name, DisplayRoot)
        }
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path -Path $Destination -ChildPath 'settings.json') -Encoding UTF8
    }

    $manifest = [ordered]@{
        SchemaVersion = 1
        CreatedUtc    = (Get-Date).ToUniversalTime().ToString('o')
        Folders       = @($folderResults)
        Files         = @()
    }

    if ($Hash -and (Test-Path -LiteralPath $stateRoot)) {
        $prefix = $stateRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        $files = foreach ($file in (Get-ChildItem -LiteralPath $stateRoot -Recurse -File -Force)) {
            [PSCustomObject]@{
                Path   = $file.FullName.Substring($prefix.Length)
                Bytes  = $file.Length
                Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        $manifest.Files = @($files)
    }

    if ($folderResults.Count -gt 0 -and $PSCmdlet.ShouldProcess($Destination, 'Write manifest.json')) {
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $Destination -ChildPath 'manifest.json') -Encoding UTF8
    }

    Write-MigrationLog -Message 'Backup finished.' -LogPath $LogPath
    [PSCustomObject]$manifest
}
