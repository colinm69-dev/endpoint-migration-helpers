function Test-RobocopyExitCode {
    <#
    .SYNOPSIS
        Returns $true when a robocopy exit code means success. Codes 0-7 are success (bit flags
        for copied, extra or mismatched files); 8 and above mean at least one failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [int]$ExitCode
    )
    return ($ExitCode -ge 0 -and $ExitCode -lt 8)
}
