function Test-PendingReboot {
    <#
    .SYNOPSIS
        Checks the common registry markers for a pending reboot. Windows only.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $keys) {
        if (Test-Path -LiteralPath $key) { return $true }
    }

    $session = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    return [bool]($session -and $session.PendingFileRenameOperations)
}
