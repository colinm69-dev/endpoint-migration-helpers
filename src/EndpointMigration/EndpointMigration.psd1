@{
    RootModule            = 'EndpointMigration.psm1'
    ModuleVersion         = '0.1.0'
    GUID                  = '6b0d6a0e-3f64-4c1e-9d0e-5f1a2b7c9e11'
    Author                = 'Colin McLaren'
    Description           = 'Generic helpers for assessing, backing up and enrolling Windows endpoints during a migration to Windows 11 and Intune.'
    PowerShellVersion     = '5.1'
    FunctionsToExport     = @(
        'Backup-UserState'
        'ConvertFrom-OsVersion'
        'Get-AnonymisedId'
        'Get-IntuneEnrollmentStatus'
        'Get-MigrationInventory'
        'Get-Win11Readiness'
        'Invoke-IntuneSync'
        'Restore-UserState'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
    PrivateData           = @{
        PSData = @{
            Tags         = @('Intune', 'Windows11', 'Migration', 'Endpoint')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
        }
    }
}
