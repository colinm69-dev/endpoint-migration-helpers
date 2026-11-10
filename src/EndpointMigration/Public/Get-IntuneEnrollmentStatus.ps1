function Get-IntuneEnrollmentStatus {
    <#
    .SYNOPSIS
        Reports how this device is joined (Domain, AzureAD, Hybrid, Registered) and whether it has an MDM enrolment.
    .PARAMETER DsregText
        Optional "dsregcmd /status" output, mainly for testing. Read from the local system when omitted.
    .EXAMPLE
        Get-IntuneEnrollmentStatus
    #>
    [CmdletBinding()]
    param(
        [string]$DsregText
    )

    if (-not $DsregText) {
        if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
            throw 'dsregcmd is only available on Windows.'
        }
        $exe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\dsregcmd.exe'
        if (-not (Test-Path -LiteralPath $exe)) {
            throw "dsregcmd.exe was not found at $exe."
        }
        $DsregText = (& $exe /status) -join [System.Environment]::NewLine
    }
    ConvertFrom-DsregStatus -Text $DsregText
}
