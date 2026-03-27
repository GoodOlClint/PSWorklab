BeforeAll {
    # Dot-source all dependencies
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-WorklabConfig.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-ConfigValue.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-TemplateRegistry.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Resolve-TemplateVmId.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Write-HclFile.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Private' 'HclFragments.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'New-LabTerraform.ps1')
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'New-LabTerraform' {
    BeforeEach {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "labterraform-test-$(Get-Random)"
        $projectDir = Join-Path $tempDir 'project'
        $labDir = Join-Path $projectDir 'terraform' 'labs' 'lab-03'
        New-Item -ItemType Directory -Path $labDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $projectDir 'build-info') -Force | Out-Null

        # worklab-config.yml
        @"
hypervisor: proxmox
networking_mode: pfsense

proxmox:
  api_url: https://pve.local:8006
  node: pve
  storage_pool: local-lvm
  sdn_zone: labzone

pfsense:
  api_url: https://10.0.0.1
  username: admin
  lab_device: vtnet1

terraform:
  role_defaults:
    dc:
      cores: 2
      memory: 4096
"@ | Set-Content -Path (Join-Path $projectDir 'worklab-config.yml') -Encoding UTF8

        # Template registry
        @"
templates:
  server-2025:
    vm_id: 9000
    proxmox:
      vm_id: 9000
"@ | Set-Content -Path (Join-Path $projectDir 'build-info' 'worklab-templates.yml') -Encoding UTF8

        # lab-config.yml (minimal, DCs only)
        @"
lab_name: lab-03
domain_name: lab03.internal
network_name: lab03
vlan_id: 103
ip_cidr: 10.103.0.0/24
gateway_ip: 10.103.0.1

infrastructure:
  dc1:
    role: dc-primary
    template: server-2025
    static_ip: 10.103.0.10
    cores: 2
    memory: 4096
  dc2:
    role: dc-replica
    template: server-2025
    static_ip: 10.103.0.11
    cores: 2
    memory: 4096
"@ | Set-Content -Path (Join-Path $labDir 'lab-config.yml') -Encoding UTF8

        $script:ProjectRoot = $projectDir
    }

    AfterEach {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        $script:ProjectRoot = $null
    }

    It 'Generates all four Terraform files' {
        $result = New-LabTerraform -LabName lab-03
        $result | Should -HaveCount 4
        Test-Path (Join-Path $labDir 'variables.tf') | Should -BeTrue
        Test-Path (Join-Path $labDir 'backend.tf') | Should -BeTrue
        Test-Path (Join-Path $labDir 'main.tf') | Should -BeTrue
        Test-Path (Join-Path $labDir 'outputs.tf') | Should -BeTrue
    }

    It 'main.tf contains proxmox provider block' {
        New-LabTerraform -LabName lab-03 | Out-Null
        $mainTf = Get-Content (Join-Path $labDir 'main.tf') -Raw
        $mainTf | Should -Match 'provider\s+"proxmox"'
        $mainTf | Should -Match 'bpg/proxmox'
    }

    It 'main.tf contains pfsense provider when networking_mode is pfsense' {
        New-LabTerraform -LabName lab-03 | Out-Null
        $mainTf = Get-Content (Join-Path $labDir 'main.tf') -Raw
        $mainTf | Should -Match 'provider\s+"pfsense"'
        $mainTf | Should -Match 'goodolclint/pfsense'
    }

    It 'main.tf contains vm_configurations with both DCs' {
        New-LabTerraform -LabName lab-03 | Out-Null
        $mainTf = Get-Content (Join-Path $labDir 'main.tf') -Raw
        $mainTf | Should -Match 'name\s+=\s+"dc1"'
        $mainTf | Should -Match 'name\s+=\s+"dc2"'
        $mainTf | Should -Match 'template_id\s+=\s+"9000"'
    }

    It 'variables.tf declares proxmox_api_token and pfsense_password' {
        New-LabTerraform -LabName lab-03 | Out-Null
        $varsTf = Get-Content (Join-Path $labDir 'variables.tf') -Raw
        $varsTf | Should -Match 'variable\s+"proxmox_api_token"'
        $varsTf | Should -Match 'variable\s+"pfsense_password"'
    }

    It 'outputs.tf has per-VM IP outputs' {
        New-LabTerraform -LabName lab-03 | Out-Null
        $outputsTf = Get-Content (Join-Path $labDir 'outputs.tf') -Raw
        $outputsTf | Should -Match 'output\s+"dc1_ip"'
        $outputsTf | Should -Match 'output\s+"dc2_ip"'
        $outputsTf | Should -Match 'output\s+"lab_name"'
    }

    It 'Generates valid HCL for flat networking mode' {
        # Switch to flat networking
        $configPath = Join-Path $projectDir 'worklab-config.yml'
        $content = (Get-Content $configPath -Raw) -replace 'networking_mode: pfsense', 'networking_mode: flat'
        Set-Content -Path $configPath -Value $content -Encoding UTF8

        $result = New-LabTerraform -LabName lab-03
        $result | Should -HaveCount 4

        $mainTf = Get-Content (Join-Path $labDir 'main.tf') -Raw
        $mainTf | Should -Not -Match 'provider\s+"pfsense"'

        $varsTf = Get-Content (Join-Path $labDir 'variables.tf') -Raw
        $varsTf | Should -Not -Match 'pfsense_password'
    }

    It 'Throws when lab-config.yml is missing' {
        { New-LabTerraform -LabName nonexistent } | Should -Throw '*Lab config not found*'
    }
}
