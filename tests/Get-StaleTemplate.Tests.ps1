BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-StaleTemplate.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-TemplateRegistry.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-WorklabConfig.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-ConfigValue.ps1')
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'Get-StaleTemplate' {
    BeforeEach {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "stale-test-$(Get-Random)"
        $projectDir = Join-Path $tempDir 'project'
        $buildInfoDir = Join-Path $projectDir 'build-info'
        New-Item -ItemType Directory -Path $buildInfoDir -Force | Out-Null

        # worklab-config.yml
        @"
hypervisor: proxmox
"@ | Set-Content -Path (Join-Path $projectDir 'worklab-config.yml') -Encoding UTF8

        $script:ProjectRoot = $projectDir
        $regPath = Join-Path $buildInfoDir 'worklab-templates.yml'
    }

    AfterEach {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        $script:ProjectRoot = $null
    }

    It 'Returns stale templates older than MaxAgeDays' {
        $oldDate = (Get-Date).AddDays(-45).ToString('o')
        @"
templates:
  server-2025:
    vm_id: 9000
    built: $oldDate
    proxmox:
      vm_id: 9000
      built: $oldDate
"@ | Set-Content -Path $regPath -Encoding UTF8

        $result = Get-StaleTemplate -MaxAgeDays 30 -RegistryPath $regPath -Hypervisor proxmox
        $result | Should -HaveCount 1
        $result[0].Name | Should -Be 'server-2025'
        $result[0].VmId | Should -Be 9000
        $result[0].AgeDays | Should -BeGreaterThan 30
    }

    It 'Does not return fresh templates' {
        $recentDate = (Get-Date).AddDays(-5).ToString('o')
        @"
templates:
  server-2025:
    vm_id: 9000
    built: $recentDate
    proxmox:
      vm_id: 9000
      built: $recentDate
"@ | Set-Content -Path $regPath -Encoding UTF8

        $result = Get-StaleTemplate -MaxAgeDays 30 -RegistryPath $regPath -Hypervisor proxmox
        $result | Should -HaveCount 0
    }

    It 'Returns all templates when MaxAgeDays is 0' {
        $recentDate = (Get-Date).AddHours(-1).ToString('o')
        @"
templates:
  server-2025:
    vm_id: 9000
    built: $recentDate
    proxmox:
      vm_id: 9000
      built: $recentDate
  server-2022:
    vm_id: 9001
    built: $recentDate
    proxmox:
      vm_id: 9001
      built: $recentDate
"@ | Set-Content -Path $regPath -Encoding UTF8

        $result = Get-StaleTemplate -MaxAgeDays 0 -RegistryPath $regPath -Hypervisor proxmox
        $result | Should -HaveCount 2
    }

    It 'Treats templates with no built date as stale' {
        @"
templates:
  server-2025:
    vm_id: 9000
    proxmox:
      vm_id: 9000
"@ | Set-Content -Path $regPath -Encoding UTF8

        $result = Get-StaleTemplate -MaxAgeDays 30 -RegistryPath $regPath -Hypervisor proxmox
        $result | Should -HaveCount 1
        $result[0].Built | Should -BeNullOrEmpty
    }

    It 'Returns mixed stale and fresh correctly' {
        $oldDate = (Get-Date).AddDays(-60).ToString('o')
        $newDate = (Get-Date).AddDays(-2).ToString('o')
        @"
templates:
  old-template:
    vm_id: 9000
    built: $oldDate
    proxmox:
      vm_id: 9000
      built: $oldDate
  new-template:
    vm_id: 9001
    built: $newDate
    proxmox:
      vm_id: 9001
      built: $newDate
"@ | Set-Content -Path $regPath -Encoding UTF8

        $result = Get-StaleTemplate -MaxAgeDays 30 -RegistryPath $regPath -Hypervisor proxmox
        $result | Should -HaveCount 1
        $result[0].Name | Should -Be 'old-template'
    }
}
