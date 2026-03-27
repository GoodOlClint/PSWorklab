BeforeAll {
    # Dot-source private helpers and the function under test
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-WorklabConfig.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-ConfigValue.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Private' 'Read-ProductDefinition.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'New-LabConfig.ps1')
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'New-LabConfig' {
    BeforeEach {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "labconfig-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Create a minimal worklab-config.yml
        $configDir = Join-Path $tempDir 'project'
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        @"
hypervisor: proxmox
networking_mode: pfsense

terraform:
  role_defaults:
    dc:
      cores: 2
      memory: 4096
    member:
      cores: 2
      memory: 4096
    sql:
      cores: 4
      memory: 8192
      data_disk_size: 100
    workgroup:
      cores: 2
      memory: 4096
"@ | Set-Content -Path (Join-Path $configDir 'worklab-config.yml') -Encoding UTF8

        $script:ProjectRoot = $configDir
        $outputDir = Join-Path $tempDir 'output'
    }

    AfterEach {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        $script:ProjectRoot = $null
    }

    It 'Generates a lab-config.yml with infrastructure VMs' {
        $result = New-LabConfig -LabName lab-03 -VlanId 103 -IpCidr '10.103.0.0/24' -Domain lab03.internal -OutputPath $outputDir
        $result | Should -Not -BeNullOrEmpty
        Test-Path $result | Should -BeTrue

        $config = Get-Content $result -Raw | ConvertFrom-Yaml
        $config.lab_name | Should -Be 'lab-03'
        $config.domain_name | Should -Be 'lab03.internal'
        $config.vlan_id | Should -Be 103
        $config.ip_cidr | Should -Be '10.103.0.0/24'
        $config.gateway_ip | Should -Be '10.103.0.1'
        $config.network_name | Should -Be 'lab03'
    }

    It 'Creates DC1 and DC2 with correct IPs and role defaults' {
        $result = New-LabConfig -LabName lab-05 -VlanId 105 -IpCidr '10.105.0.0/24' -Domain lab05.internal -OutputPath $outputDir
        $config = Get-Content $result -Raw | ConvertFrom-Yaml

        $config.infrastructure.dc1.role | Should -Be 'dc-primary'
        $config.infrastructure.dc1.static_ip | Should -Be '10.105.0.10'
        $config.infrastructure.dc1.cores | Should -Be 2
        $config.infrastructure.dc1.memory | Should -Be 4096

        $config.infrastructure.dc2.role | Should -Be 'dc-replica'
        $config.infrastructure.dc2.static_ip | Should -Be '10.105.0.11'
    }

    It 'Works without any products' {
        $result = New-LabConfig -LabName lab-01 -VlanId 101 -IpCidr '10.101.0.0/24' -Domain lab01.internal -OutputPath $outputDir
        $config = Get-Content $result -Raw | ConvertFrom-Yaml

        $config.infrastructure.Keys | Should -HaveCount 2
        $config.Contains('products') | Should -BeFalse
    }

    It 'Loads product VMs when products are specified' {
        # Create a product definition
        $productsDir = Join-Path $configDir 'products'
        New-Item -ItemType Directory -Path $productsDir -Force | Out-Null
        @"
name: Test Product
short_name: tprod

versions:
  "1.0":
    vms:
      - name: web1
        role: member
        template: server-2025
      - name: db1
        role: sql
        template: server-2025-sql2022
        cores: 8
        memory: 16384
"@ | Set-Content -Path (Join-Path $productsDir 'testprod.yml') -Encoding UTF8

        $result = New-LabConfig -LabName lab-03 -VlanId 103 -IpCidr '10.103.0.0/24' -Domain lab03.internal -Products @('testprod:1.0') -OutputPath $outputDir
        $config = Get-Content $result -Raw | ConvertFrom-Yaml

        $config.products.tprod.version | Should -Be '1.0'
        $config.products.tprod.vms.'tprod-web1'.role | Should -Be 'member'
        $config.products.tprod.vms.'tprod-web1'.cores | Should -Be 2  # role default
        $config.products.tprod.vms.'tprod-db1'.role | Should -Be 'sql'
        $config.products.tprod.vms.'tprod-db1'.cores | Should -Be 8  # product override
        $config.products.tprod.vms.'tprod-db1'.memory | Should -Be 16384
        $config.products.tprod.vms.'tprod-db1'.data_disk_size | Should -Be 100  # role default
    }

    It 'Does not write with -WhatIf' {
        $result = New-LabConfig -LabName lab-01 -VlanId 101 -IpCidr '10.101.0.0/24' -Domain lab01.internal -OutputPath $outputDir -WhatIf
        Test-Path $outputDir | Should -BeFalse
    }

    It 'Throws for invalid product spec format' {
        { New-LabConfig -LabName lab-01 -VlanId 101 -IpCidr '10.101.0.0/24' -Domain lab01.internal -Products @('badformat') -OutputPath $outputDir } |
            Should -Throw '*Expected format*'
    }
}
