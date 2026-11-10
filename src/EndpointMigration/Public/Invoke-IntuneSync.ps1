function Invoke-IntuneSync {
    <#
    .SYNOPSIS
        Asks the local device to check in with Intune by starting the enrolment sync tasks.
    .DESCRIPTION
        Best effort. It starts the scheduled tasks that the MDM enrolment client creates under
        \Microsoft\Windows\EnterpriseMgmt. The supported ways to force a sync are Settings >
        Accounts > Access work or school > Info > Sync, Company Portal, or the Intune admin centre.
        Needs an elevated session.
    .EXAMPLE
        Invoke-IntuneSync -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this from an elevated (administrator) session.'
    }

    $tasks = @(Get-ScheduledTask -TaskPath '\Microsoft\Windows\EnterpriseMgmt\*' -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -like 'Schedule*' })

    if ($tasks.Count -eq 0) {
        Write-Warning 'No MDM sync tasks were found. The device may not be enrolled in Intune.'
        return 0
    }

    $started = 0
    foreach ($task in $tasks) {
        if ($PSCmdlet.ShouldProcess($task.TaskName, 'Start MDM sync task')) {
            Start-ScheduledTask -InputObject $task
            $started++
        }
    }
    return $started
}
