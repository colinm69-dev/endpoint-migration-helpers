# Loads every function file. Private functions stay internal; Public functions are exported.
$publicFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$privateFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($privateFiles + $publicFiles)) {
    . $file.FullName
}

Export-ModuleMember -Function $publicFiles.BaseName
