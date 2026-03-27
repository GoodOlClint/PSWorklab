BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Register-Template.ps1')
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'Register-Template' {
    BeforeEach {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "reg-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $regPath = Join-Path $tempDir 'worklab-templates.yml'
    }

    AfterEach {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    }

    It 'Creates a new registry file when none exists' {
        Register-Template -TemplateName server-2025 -VmId 9001 -Hypervisor proxmox -RegistryPath $regPath
        Test-Path $regPath | Should -BeTrue
        $content = Get-Content $regPath -Raw | ConvertFrom-Yaml
        $content.templates.'server-2025'.proxmox.vm_id | Should -Be 9001
    }

    It 'Adds a second template to an existing registry' {
        Register-Template -TemplateName server-2025 -VmId 9001 -Hypervisor proxmox -RegistryPath $regPath
        Register-Template -TemplateName server-2022 -VmId 9002 -Hypervisor proxmox -RegistryPath $regPath
        $content = Get-Content $regPath -Raw | ConvertFrom-Yaml
        $content.templates.'server-2025'.proxmox.vm_id | Should -Be 9001
        $content.templates.'server-2022'.proxmox.vm_id | Should -Be 9002
    }

    It 'Updates an existing template entry' {
        Register-Template -TemplateName server-2025 -VmId 9001 -Hypervisor proxmox -RegistryPath $regPath
        Register-Template -TemplateName server-2025 -VmId 9010 -Hypervisor proxmox -RegistryPath $regPath
        $content = Get-Content $regPath -Raw | ConvertFrom-Yaml
        $content.templates.'server-2025'.proxmox.vm_id | Should -Be 9010
    }

    It 'Writes backward-compatible flat fields' {
        Register-Template -TemplateName server-2025 -VmId 9001 -Hypervisor proxmox -RegistryPath $regPath
        $content = Get-Content $regPath -Raw | ConvertFrom-Yaml
        $content.templates.'server-2025'.vm_id | Should -Be 9001
        $content.templates.'server-2025'.built | Should -Not -BeNullOrEmpty
    }

    It 'Includes SQL version when specified' {
        Register-Template -TemplateName server-2025-sql2022 -VmId 9002 -Hypervisor proxmox -SqlVersion 2022 -RegistryPath $regPath
        $content = Get-Content $regPath -Raw | ConvertFrom-Yaml
        $content.templates.'server-2025-sql2022'.proxmox.sql_version | Should -Be '2022'
        $content.templates.'server-2025-sql2022'.sql_version | Should -Be '2022'
    }

    It 'Includes a header comment' {
        Register-Template -TemplateName server-2025 -VmId 9001 -Hypervisor proxmox -RegistryPath $regPath
        $raw = Get-Content $regPath -Raw
        $raw | Should -Match '^# build-info/worklab-templates.yml'
    }

    It 'Does not write with -WhatIf' {
        Register-Template -TemplateName server-2025 -VmId 9001 -Hypervisor proxmox -RegistryPath $regPath -WhatIf
        Test-Path $regPath | Should -BeFalse
    }
}
