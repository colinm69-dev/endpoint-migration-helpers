function ConvertFrom-DsregStatus {
    <#
    .SYNOPSIS
        Parses the text output of "dsregcmd /status" into an object. Pure parsing, no system calls.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $values = @{}
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*([A-Za-z][A-Za-z0-9]*)\s*:\s*(.*?)\s*$') {
            $key = $Matches[1]
            if (-not $values.ContainsKey($key)) {
                $values[$key] = $Matches[2]
            }
        }
    }

    function Get-Flag {
        param([string]$Key)
        return ($values.ContainsKey($Key) -and $values[$Key] -eq 'YES')
    }

    $azureAd = Get-Flag 'AzureAdJoined'
    $domain = Get-Flag 'DomainJoined'
    $workplace = Get-Flag 'WorkplaceJoined'
    $mdmUrl = if ($values.ContainsKey('MdmUrl')) { $values['MdmUrl'] } else { '' }

    $joinType = 'None'
    if ($azureAd -and $domain) { $joinType = 'Hybrid' }
    elseif ($azureAd) { $joinType = 'AzureAD' }
    elseif ($domain) { $joinType = 'Domain' }
    elseif ($workplace) { $joinType = 'Registered' }

    [PSCustomObject]@{
        JoinType       = $joinType
        AzureAdJoined  = $azureAd
        DomainJoined   = $domain
        WorkplaceJoined = $workplace
        MdmEnrolled    = ($mdmUrl -match '^https?://')
        HasPrimaryRefreshToken = (Get-Flag 'AzureAdPrt')
        TenantName     = $(if ($values.ContainsKey('TenantName')) { $values['TenantName'] } else { '' })
    }
}
