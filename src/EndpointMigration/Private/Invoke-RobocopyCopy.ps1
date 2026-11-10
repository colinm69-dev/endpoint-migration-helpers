function Invoke-RobocopyCopy {
    <#
    .SYNOPSIS
        Thin wrapper around robocopy.exe so the rest of the module can be tested without it.
    .OUTPUTS
        The robocopy exit code. Use Test-RobocopyExitCode to interpret it.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [string[]]$ExtraOption = @(),

        [string]$LogFile
    )

    $arguments = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:1', '/W:1', '/XJ', '/NP', '/NFL', '/NDL', '/MT:8') + $ExtraOption
    if ($LogFile) {
        $arguments += "/LOG+:$LogFile"
    }
    $null = & robocopy.exe @arguments
    return $LASTEXITCODE
}
