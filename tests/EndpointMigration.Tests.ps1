BeforeAll {
    $script:ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\EndpointMigration\EndpointMigration.psd1'
    Import-Module $script:ModulePath -Force
    $script:Fixtures = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures'
}

Describe 'Module manifest' {
    It 'is valid' {
        { Test-ModuleManifest -Path $script:ModulePath -ErrorAction Stop } | Should -Not -Throw
    }
    It 'exports the documented functions' {
        $exported = (Get-Module EndpointMigration).ExportedFunctions.Keys
        foreach ($name in 'Backup-UserState', 'Restore-UserState', 'Get-Win11Readiness', 'Get-IntuneEnrollmentStatus',
            'Get-MigrationInventory', 'Invoke-IntuneSync', 'Get-AnonymisedId', 'ConvertFrom-OsVersion') {
            $exported | Should -Contain $name
        }
    }
    It 'does not export private helpers' {
        (Get-Module EndpointMigration).ExportedFunctions.Keys | Should -Not -Contain 'Resolve-ReadinessVerdict'
    }
}

Describe 'Get-AnonymisedId' {
    It 'is stable for the same value and salt' {
        (Get-AnonymisedId -Value 'PC-0001' -Salt 's1') | Should -BeExactly (Get-AnonymisedId -Value 'PC-0001' -Salt 's1')
    }
    It 'ignores case and surrounding spaces' {
        (Get-AnonymisedId -Value ' pc-0001 ' -Salt 's1') | Should -BeExactly (Get-AnonymisedId -Value 'PC-0001' -Salt 's1')
    }
    It 'changes with the salt' {
        (Get-AnonymisedId -Value 'PC-0001' -Salt 's1') | Should -Not -BeExactly (Get-AnonymisedId -Value 'PC-0001' -Salt 's2')
    }
    It 'does not contain the original value' {
        (Get-AnonymisedId -Value 'PC-0001' -Salt 's1' -Prefix 'dev') | Should -Match '^dev-[0-9a-f]{10}$'
    }
}

Describe 'ConvertFrom-OsVersion' {
    It 'treats build <Build> as <Family>' -ForEach @(
        @{ Version = '10.0.19045.4651'; Build = 19045; Family = 'Windows 10' }
        @{ Version = '10.0.22000.1'; Build = 22000; Family = 'Windows 11' }
        @{ Version = '10.0.26100.2033'; Build = 26100; Family = 'Windows 11' }
    ) {
        $r = ConvertFrom-OsVersion -OsVersion $Version
        $r.Valid | Should -BeTrue
        $r.Build | Should -Be $Build
        $r.Family | Should -Be $Family
    }
    It 'marks garbage as invalid' {
        (ConvertFrom-OsVersion -OsVersion 'not a version').Valid | Should -BeFalse
        (ConvertFrom-OsVersion -OsVersion '').Family | Should -Be 'Unknown'
    }
}

Describe 'Private helpers' {
    BeforeAll {
        $script:Good = [PSCustomObject]@{
            TpmPresent = $true; TpmVersion = '2.0'; UefiBoot = $true; SecureBootEnabled = $true
            RamGB = 16; SystemDiskGB = 256; CpuCores = 8; CpuClockMHz = 3000; Cpu64Bit = $true; OsBuild = 19045
        }
    }

    Context 'Resolve-ReadinessVerdict' {
        It 'returns Ready when everything passes' {
            InModuleScope EndpointMigration -Parameters @{ Facts = $script:Good } {
                (Resolve-ReadinessVerdict -Facts $Facts).Verdict | Should -Be 'Ready'
            }
        }
        It 'returns ReadyAfterChange when only Secure Boot is off' {
            $facts = $script:Good.PSObject.Copy()
            $facts.SecureBootEnabled = $false
            InModuleScope EndpointMigration -Parameters @{ Facts = $facts } {
                $r = Resolve-ReadinessVerdict -Facts $Facts
                $r.Verdict | Should -Be 'ReadyAfterChange'
                $r.Fixable.Count | Should -Be 1
            }
        }
        It 'returns NotReady with 2 GB of RAM' {
            $facts = $script:Good.PSObject.Copy()
            $facts.RamGB = 2
            InModuleScope EndpointMigration -Parameters @{ Facts = $facts } {
                $r = Resolve-ReadinessVerdict -Facts $Facts
                $r.Verdict | Should -Be 'NotReady'
                $r.Blockers.Count | Should -Be 1
            }
        }
        It 'returns NotReady with TPM 1.2' {
            $facts = $script:Good.PSObject.Copy()
            $facts.TpmVersion = '1.2'
            InModuleScope EndpointMigration -Parameters @{ Facts = $facts } {
                (Resolve-ReadinessVerdict -Facts $Facts).Verdict | Should -Be 'NotReady'
            }
        }
        It 'flags a device already on Windows 11' {
            $facts = $script:Good.PSObject.Copy()
            $facts.OsBuild = 22631
            InModuleScope EndpointMigration -Parameters @{ Facts = $facts } {
                (Resolve-ReadinessVerdict -Facts $Facts).AlreadyWindows11 | Should -BeTrue
            }
        }
    }

    Context 'ConvertFrom-DsregStatus' {
        It 'detects a hybrid joined, MDM enrolled device' {
            $text = Get-Content -LiteralPath (Join-Path $script:Fixtures 'dsreg-hybrid.txt') -Raw
            InModuleScope EndpointMigration -Parameters @{ Text = $text } {
                $r = ConvertFrom-DsregStatus -Text $Text
                $r.JoinType | Should -Be 'Hybrid'
                $r.MdmEnrolled | Should -BeTrue
                $r.HasPrimaryRefreshToken | Should -BeTrue
            }
        }
        It 'detects a device that is not joined' {
            $text = Get-Content -LiteralPath (Join-Path $script:Fixtures 'dsreg-none.txt') -Raw
            InModuleScope EndpointMigration -Parameters @{ Text = $text } {
                $r = ConvertFrom-DsregStatus -Text $Text
                $r.JoinType | Should -Be 'None'
                $r.MdmEnrolled | Should -BeFalse
            }
        }
        It 'copes with empty input' {
            InModuleScope EndpointMigration {
                (ConvertFrom-DsregStatus -Text '').JoinType | Should -Be 'None'
            }
        }
    }

    Context 'Test-RobocopyExitCode' {
        It 'treats <Code> as success=<Expected>' -ForEach @(
            @{ Code = 0; Expected = $true }, @{ Code = 1; Expected = $true }, @{ Code = 3; Expected = $true },
            @{ Code = 7; Expected = $true }, @{ Code = 8; Expected = $false }, @{ Code = 16; Expected = $false }
        ) {
            InModuleScope EndpointMigration -Parameters @{ Code = $Code; Expected = $Expected } {
                (Test-RobocopyExitCode -ExitCode $Code) | Should -Be $Expected
            }
        }
    }

    Context 'Test-PathInside' {
        It 'detects a child path' {
            InModuleScope EndpointMigration {
                Test-PathInside -Parent 'C:\Users\Example' -Child 'C:\Users\Example\Backup' | Should -BeTrue
            }
        }
        It 'does not confuse similar names' {
            InModuleScope EndpointMigration {
                Test-PathInside -Parent 'C:\Users\Example' -Child 'C:\Users\Example2' | Should -BeFalse
            }
        }
    }
}
