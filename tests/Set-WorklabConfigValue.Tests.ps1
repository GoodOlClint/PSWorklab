BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Set-WorklabConfigValue.ps1')
}

Describe 'Set-WorklabConfigValue' {
    BeforeEach {
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-config-$(Get-Random).yml"
        @"
hypervisor: proxmox

proxmox:
  api_url: https://pve.local:8006
  api_token_id: root@pam!worklab
  node: pve
  storage: local-lvm  # main storage

pfsense:
  api_url: https://10.101.0.1
"@ | Set-Content -Path $tempFile -Encoding UTF8
    }

    AfterEach {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }

    It 'Updates a simple key value' {
        Set-WorklabConfigValue -Section proxmox -Key node -Value 'pve2' -ConfigPath $tempFile
        $content = Get-Content $tempFile -Raw
        $content | Should -Match '  node: pve2'
    }

    It 'Preserves inline comments' {
        Set-WorklabConfigValue -Section proxmox -Key storage -Value 'zfs-pool' -ConfigPath $tempFile
        $content = Get-Content $tempFile -Raw
        $content | Should -Match '  storage: zfs-pool  # main storage'
    }

    It 'Only modifies the target section' {
        Set-WorklabConfigValue -Section pfsense -Key api_url -Value 'https://10.101.0.2' -ConfigPath $tempFile
        $content = Get-Content $tempFile -Raw
        $content | Should -Match 'proxmox:'
        $content | Should -Match '  api_url: https://pve.local:8006'
        $content | Should -Match '  api_url: https://10.101.0.2'
    }

    It 'Warns when key is not found' {
        Set-WorklabConfigValue -Section proxmox -Key nonexistent -Value 'x' -ConfigPath $tempFile 3>&1 |
            Should -Match 'Could not find'
    }

    It 'Does not modify file with -WhatIf' {
        $before = Get-Content $tempFile -Raw
        Set-WorklabConfigValue -Section proxmox -Key node -Value 'changed' -ConfigPath $tempFile -WhatIf
        $after = Get-Content $tempFile -Raw
        $after | Should -Be $before
    }

    It 'Does not emit false warning with -WhatIf when key exists' {
        $warnings = Set-WorklabConfigValue -Section proxmox -Key node -Value 'changed' -ConfigPath $tempFile -WhatIf 3>&1
        $warnings | Should -BeNullOrEmpty
    }
}
