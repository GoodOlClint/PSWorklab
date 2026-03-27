BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Resolve-TemplateVmId.ps1')
}

Describe 'Resolve-TemplateVmId' {
    BeforeAll {
        # Registry with both nested and flat formats
        $registry = @{
            templates = @{
                'server-2025' = @{
                    proxmox = @{ vm_id = 9001; built = '2025-01-15T10:00:00' }
                    vm_id   = 9001
                    built   = '2025-01-15T10:00:00'
                }
                'server-2022' = @{
                    proxmox = @{ vm_id = 9002; built = '2025-01-10T10:00:00' }
                    vm_id   = 9002
                }
                'legacy-flat-only' = @{
                    vm_id = 9003
                }
            }
        }
    }

    It 'Resolves a template name to VM ID (nested format)' {
        $result = Resolve-TemplateVmId -TemplateName 'server-2025' -Hypervisor 'proxmox' -Registry $registry
        $result.VmId | Should -Be 9001
        $result.Name | Should -Be 'server-2025'
    }

    It 'Falls back to flat format when hypervisor key is missing' {
        $result = Resolve-TemplateVmId -TemplateName 'legacy-flat-only' -Hypervisor 'proxmox' -Registry $registry
        $result.VmId | Should -Be 9003
        $result.Name | Should -Be 'legacy-flat-only'
    }

    It 'Performs reverse lookup from VM ID to name' {
        $result = Resolve-TemplateVmId -TemplateName '9002' -Hypervisor 'proxmox' -Registry $registry
        $result.VmId | Should -Be 9002
        $result.Name | Should -Be 'server-2022'
    }

    It 'Returns null name for unrecognized VM ID' {
        $result = Resolve-TemplateVmId -TemplateName '9999' -Hypervisor 'proxmox' -Registry $registry
        $result.VmId | Should -Be 9999
        $result.Name | Should -BeNullOrEmpty
    }

    It 'Throws for missing template name' {
        { Resolve-TemplateVmId -TemplateName 'nonexistent' -Hypervisor 'proxmox' -Registry $registry } |
            Should -Throw '*not found in registry*'
    }

    It 'Throws when template has no VM ID for the hypervisor' {
        $badRegistry = @{
            templates = @{
                'no-vmid' = @{ some_other_key = 'value' }
            }
        }
        { Resolve-TemplateVmId -TemplateName 'no-vmid' -Hypervisor 'proxmox' -Registry $badRegistry } |
            Should -Throw '*no entry for hypervisor*'
    }
}
