@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Intune scripts and log helpers use Write-Output on purpose: stdout is what Intune reports.
        'PSAvoidUsingWriteHost'
    )
}
