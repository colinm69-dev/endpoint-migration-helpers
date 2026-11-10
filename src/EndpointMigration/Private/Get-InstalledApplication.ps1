function Get-InstalledApplication {
    <#
    .SYNOPSIS
        Lists installed desktop applications from the Uninstall registry keys (64-bit and 32-bit).
    #>
    [CmdletBinding()]
    param()

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
        Select-Object -Property @{ Name = 'Name'; Expression = { $_.DisplayName } },
        @{ Name = 'Version'; Expression = { $_.DisplayVersion } },
        @{ Name = 'Publisher'; Expression = { $_.Publisher } } |
        Sort-Object -Property Name -Unique
}
