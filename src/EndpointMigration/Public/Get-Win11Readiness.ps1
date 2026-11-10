function Get-Win11Readiness {
    <#
    .SYNOPSIS
        Checks whether this device meets the Windows 11 hardware requirements.
    .DESCRIPTION
        Collects TPM, firmware, memory, disk and CPU facts and returns a verdict (Ready,
        ReadyAfterChange or NotReady) with the individual checks and what to fix.
        The CPU model is not checked against Microsoft's supported processor list.
    .PARAMETER Facts
        Optional pre-collected facts, mainly for testing. Collected from the local system when omitted.
    .EXAMPLE
        Get-Win11Readiness | Select-Object Verdict, Blockers, Fixable
    #>
    [CmdletBinding()]
    param(
        [PSCustomObject]$Facts
    )

    if (-not $Facts) {
        $Facts = Get-SystemFact
    }
    Resolve-ReadinessVerdict -Facts $Facts
}
