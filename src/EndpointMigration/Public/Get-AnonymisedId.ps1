function Get-AnonymisedId {
    <#
    .SYNOPSIS
        Replaces a sensitive value (a computer or user name) with a short, stable, salted identifier.
    .DESCRIPTION
        The same value and salt always give the same identifier, so reports can be compared over
        time without exposing real names. Keep the salt private: anyone with the salt can test
        guesses against the identifiers.
    .EXAMPLE
        Get-AnonymisedId -Value 'LAPTOP-0042' -Salt 'my-private-salt' -Prefix 'dev'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Salt,

        [string]$Prefix = 'id'
    )

    process {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Salt + '|' + $Value.Trim().ToLowerInvariant())
            $hash = $sha.ComputeHash($bytes)
        }
        finally {
            $sha.Dispose()
        }
        $hex = ($hash[0..4] | ForEach-Object { $_.ToString('x2') }) -join ''
        '{0}-{1}' -f $Prefix, $hex
    }
}
