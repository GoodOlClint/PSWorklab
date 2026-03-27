function New-LabConfig {
    <#
    .SYNOPSIS
        Generates a lab-config.yml from lab parameters and product definitions.
    .DESCRIPTION
        Builds the unified VM list (infrastructure DCs + product VMs), applies role
        defaults from worklab-config.yml, and writes the result as an editable
        lab-config.yml file.

        The generated file can be edited (change VM sizes, swap templates) before
        running New-LabTerraform to generate the Terraform files.
    .PARAMETER LabName
        Lab name (e.g., lab-03). Used for directory naming and VM tags.
    .PARAMETER VlanId
        VLAN ID for the lab network (100-999).
    .PARAMETER IpCidr
        IP CIDR for the lab subnet (e.g., 10.103.0.0/24).
    .PARAMETER Domain
        Active Directory domain name (e.g., lab03.internal).
    .PARAMETER Products
        Array of product specs in "name:version" format (e.g., "myproduct:1.0").
        Optional -- DCs are always created.
    .PARAMETER OutputPath
        Directory to write lab-config.yml into. Defaults to terraform/labs/$LabName/.
    .EXAMPLE
        New-LabConfig -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal
    .EXAMPLE
        New-LabConfig -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal -Products @("myproduct:1.0")
    .OUTPUTS
        System.String -- path to the generated lab-config.yml.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$LabName,

        [Parameter(Mandatory)]
        [ValidateRange(100, 999)]
        [int]$VlanId,

        [Parameter(Mandatory)]
        [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$')]
        [string]$IpCidr,

        [Parameter(Mandatory)]
        [string]$Domain,

        [string[]]$Products,

        [string]$OutputPath
    )

    if (-not $script:ProjectRoot) {
        throw "Project root not set. Call Initialize-WorklabContext first."
    }

    $config = Get-WorklabConfig
    $roleDefaults = Get-ConfigValue $config 'terraform.role_defaults' @{}

    # Derive network parameters
    $cidrParts = $IpCidr -split '/'
    $networkOctets = ($cidrParts[0]) -split '\.'
    $subnetBase = "$($networkOctets[0]).$($networkOctets[1]).$($networkOctets[2])"
    $gatewayIp = "$subnetBase.1"
    $dc1Ip = "$subnetBase.10"
    $dc2Ip = "$subnetBase.11"
    $networkName = $LabName -replace '-', ''

    # Get DC role defaults
    $dcDefaults = if ($roleDefaults.Contains('dc')) { $roleDefaults.dc } else { @{ cores = 2; memory = 4096 } }

    # Build infrastructure VMs (always present)
    $infrastructure = [ordered]@{
        dc1 = [ordered]@{
            role      = 'dc-primary'
            template  = 'server-2025'
            static_ip = $dc1Ip
            cores     = $dcDefaults.cores
            memory    = $dcDefaults.memory
        }
        dc2 = [ordered]@{
            role      = 'dc-replica'
            template  = 'server-2025'
            static_ip = $dc2Ip
            cores     = $dcDefaults.cores
            memory    = $dcDefaults.memory
        }
    }

    # Build product VMs
    $productConfigs = [ordered]@{}
    foreach ($productSpec in $Products) {
        if (-not $productSpec) { continue }

        $parts = $productSpec -split ':', 2
        if ($parts.Count -ne 2) {
            throw "Invalid product spec '$productSpec'. Expected format: name:version"
        }

        $prodDef = Read-ProductDefinition -Name $parts[0] -Version $parts[1]
        $prodVMs = [ordered]@{}

        foreach ($vm in $prodDef.VMs) {
            $vmKey = "$($prodDef.ShortName)-$($vm.name)"
            $roleName = $vm.role
            $defaultsKey = if ($roleName -match '^dc-') { 'dc' } else { $roleName }
            $defaults = if ($roleDefaults.Contains($defaultsKey)) { $roleDefaults[$defaultsKey] } else { @{ cores = 2; memory = 4096 } }

            $vmConfig = [ordered]@{
                role            = $vm.role
                template        = $vm.template
                service_account = if ($vm.Contains('service_account')) { $vm.service_account } else { 'regular' }
                cores           = if ($vm.Contains('cores')) { $vm.cores } else { $defaults.cores }
                memory          = if ($vm.Contains('memory')) { $vm.memory } else { $defaults.memory }
            }

            if ($vm.role -eq 'sql') {
                $defaultDataDisk = if ($defaults.Contains('data_disk_size')) { $defaults.data_disk_size } else { 100 }
                $vmConfig.data_disk_size = if ($vm.Contains('data_disk_size')) { $vm.data_disk_size } else { $defaultDataDisk }
            }

            $prodVMs[$vmKey] = $vmConfig
        }

        $productConfigs[$prodDef.ShortName] = [ordered]@{
            version = $prodDef.Version
            vms     = $prodVMs
        }
    }

    # Build the lab-config.yml structure
    $labConfig = [ordered]@{
        lab_name     = $LabName
        domain_name  = $Domain
        network_name = $networkName
        vlan_id      = $VlanId
        ip_cidr      = $IpCidr
        gateway_ip   = $gatewayIp
        infrastructure = $infrastructure
    }

    if ($productConfigs.Count -gt 0) {
        $labConfig.products = $productConfigs
    }

    # Determine output path
    if (-not $OutputPath) {
        $OutputPath = Join-Path $script:ProjectRoot "terraform" "labs" $LabName
    }

    $configFile = Join-Path $OutputPath "lab-config.yml"

    if ($PSCmdlet.ShouldProcess($configFile, "Generate lab configuration")) {
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }

        $yamlContent = "# Lab configuration for $LabName -- edit VM sizes/templates before running New-LabTerraform`n"
        $yamlContent += ($labConfig | ConvertTo-Yaml)
        Set-Content -Path $configFile -Value $yamlContent -Encoding UTF8

        Write-Host "  Generated: $configFile" -ForegroundColor Green
        return $configFile
    }
}
