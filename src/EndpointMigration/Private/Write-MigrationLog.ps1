function Write-MigrationLog {
    <#
    .SYNOPSIS
        Writes a timestamped message to the console streams and, optionally, to a log file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [string]$LogPath
    )

    $stamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    $line = '{0} [{1}] {2}' -f $stamp, $Level.ToUpper(), $Message

    switch ($Level) {
        'Warning' { Write-Warning -Message $Message }
        'Error' { Write-Error -Message $Message -ErrorAction Continue }
        default { Write-Information -MessageData $line -InformationAction Continue }
    }

    if ($LogPath) {
        $directory = Split-Path -Parent $LogPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    }
}
