function Test-PathInside {
    <#
    .SYNOPSIS
        Returns $true when Child is the same as, or inside, Parent. Used to stop a backup being
        written into the folder it is copying from.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Parent,

        [Parameter(Mandatory)]
        [string]$Child
    )

    $separators = [char[]]@('\', '/')
    $parentFull = ([System.IO.Path]::GetFullPath($Parent)).TrimEnd($separators)
    $childFull = ([System.IO.Path]::GetFullPath($Child)).TrimEnd($separators)

    if ($childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $childFull.StartsWith($parentFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
        $childFull.StartsWith($parentFull + '/', [System.StringComparison]::OrdinalIgnoreCase) -or
        $childFull.StartsWith($parentFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
}
