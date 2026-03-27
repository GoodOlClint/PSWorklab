BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-ConfigValue.ps1')
}

Describe 'Get-ConfigValue' {
    BeforeAll {
        $config = @{
            hypervisor = 'proxmox'
            proxmox    = @{
                api_url      = 'https://pve.local:8006'
                node         = 'pve'
                storage      = 'local-lvm'
                skip_cert_check = $true
            }
            networking_mode = 'pfsense'
            empty_value     = ''
            null_value      = $null
        }
    }

    It 'Returns a top-level value' {
        Get-ConfigValue $config 'hypervisor' | Should -Be 'proxmox'
    }

    It 'Returns a nested value via dot path' {
        Get-ConfigValue $config 'proxmox.api_url' | Should -Be 'https://pve.local:8006'
    }

    It 'Returns a deeply nested value' {
        Get-ConfigValue $config 'proxmox.node' | Should -Be 'pve'
    }

    It 'Returns the default when key is missing' {
        Get-ConfigValue $config 'nonexistent' 'fallback' | Should -Be 'fallback'
    }

    It 'Returns the default when nested key is missing' {
        Get-ConfigValue $config 'proxmox.missing_key' 'fallback' | Should -Be 'fallback'
    }

    It 'Returns the default when path prefix does not exist' {
        Get-ConfigValue $config 'bogus.deep.path' 'fallback' | Should -Be 'fallback'
    }

    It 'Returns the default for empty string values' {
        Get-ConfigValue $config 'empty_value' 'fallback' | Should -Be 'fallback'
    }

    It 'Returns the default for null values' {
        Get-ConfigValue $config 'null_value' 'fallback' | Should -Be 'fallback'
    }

    It 'Returns $null when no default is specified and key is missing' {
        Get-ConfigValue $config 'nonexistent' | Should -BeNullOrEmpty
    }

    It 'Returns boolean values correctly' {
        Get-ConfigValue $config 'proxmox.skip_cert_check' $false | Should -BeTrue
    }
}
