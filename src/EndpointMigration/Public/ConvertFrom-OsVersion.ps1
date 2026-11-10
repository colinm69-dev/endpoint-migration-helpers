function ConvertFrom-OsVersion {
    <#
    .SYNOPSIS
        Splits a Windows version string such as 10.0.22631.4460 and says whether it is Windows 11.
    .DESCRIPTION
        Windows 10 and Windows 11 both report major version 10. Build 22000 and above is Windows 11.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$OsVersion
    )

    process {
        $parts = $OsVersion.Trim() -split '\.'
        $valid = ($parts.Count -ge 3) -and ($parts[0] -match '^\d+$') -and ($parts[2] -match '^\d+$')
        if (-not $valid) {
            return [PSCustomObject]@{ Valid = $false; Major = $null; Build = $null; Revision = $null; Family = 'Unknown' }
        }
        $build = [int]$parts[2]
        $revision = $null
        if ($parts.Count -ge 4 -and $parts[3] -match '^\d+$') { $revision = [int]$parts[3] }

        $family = 'Other'
        if ([int]$parts[0] -eq 10) {
            $family = if ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
        }
        [PSCustomObject]@{
            Valid    = $true
            Major    = [int]$parts[0]
            Build    = $build
            Revision = $revision
            Family   = $family
        }
    }
}
