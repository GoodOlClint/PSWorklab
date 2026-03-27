# Private HCL generation functions used by New-LabTerraform.
# Each function returns an HCL string fragment.

function Get-VariablesHcl {
    param ([string]$Hypervisor, [string]$NetworkingMode)

    $hcl = "# Lab Variables -- secrets only, injected via TF_VAR_*`n`n"

    $hcl += switch ($Hypervisor) {
        'proxmox' {
@'
variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token in 'user@realm!tokenname=secret' format."
}

'@
        }
        'vmware' {
@'
variable "vsphere_password" {
  type        = string
  sensitive   = true
  description = "vSphere password for Terraform provider authentication."
}

'@
        }
        'hyperv' {
@'
variable "hyperv_password" {
  type        = string
  sensitive   = true
  description = "Hyper-V host password for WinRM authentication."
}

'@
        }
    }

    if ($NetworkingMode -eq 'pfsense') {
        $hcl += @'
variable "pfsense_password" {
  type        = string
  sensitive   = true
  description = "pfSense admin password for REST API authentication."
}

'@
    }

    return $hcl
}

function Get-BackendHcl {
    return "# Terraform Backend -- local state. Migrate to S3/MinIO when available.`n"
}

function Get-RequiredProvidersBlock {
    param ([string]$Hypervisor, [string]$NetworkingMode)

    $providers = switch ($Hypervisor) {
        'proxmox' {
@"
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.84"
    }
"@
        }
        'vmware' {
@"
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
"@
        }
        'hyperv' {
@"
    hyperv = {
      source  = "taliesins/hyperv"
      version = "~> 1.2"
    }
"@
        }
    }

    if ($NetworkingMode -eq 'pfsense') {
        $providers += @"

    pfsense = {
      source  = "goodolclint/pfsense"
      version = "~> 0.1"
    }
"@
    }

    return $providers
}

function Get-ProviderConfigBlocks {
    param ([string]$Hypervisor, [string]$NetworkingMode)

    $blocks = switch ($Hypervisor) {
        'proxmox' {
@'
provider "proxmox" {
  endpoint  = local.config.proxmox.api_url
  api_token = var.proxmox_api_token
  insecure  = true
}
'@
        }
        'vmware' {
@'
provider "vsphere" {
  vsphere_server       = local.config.vmware.vcenter_url
  user                 = local.config.vmware.username
  password             = var.vsphere_password
  allow_unverified_ssl = true
}
'@
        }
        'hyperv' {
@'
provider "hyperv" {
  host     = local.config.hyperv.host
  user     = local.config.hyperv.username
  password = var.hyperv_password
}
'@
        }
    }

    if ($NetworkingMode -eq 'pfsense') {
        $blocks += @'

provider "pfsense" {
  url                      = local.config.pfsense.api_url
  username                 = local.config.pfsense.username
  password                 = var.pfsense_password
  tls_insecure_skip_verify = true
}
'@
    }

    return $blocks
}

function Get-LabNetworkModuleBlock {
    param (
        [string]$Hypervisor,
        [string]$NetworkingMode,
        [string]$LabName,
        [string]$NetworkName,
        [int]$VlanId,
        [string]$IpCidr,
        [string]$GatewayIp
    )

    $hypervisorConfig = switch ($Hypervisor) {
        'proxmox' { '{ sdn_zone = local.config.proxmox.sdn_zone }' }
        'vmware'  { '{ dvs_name = local.config.vmware.dvs_name }' }
        'hyperv'  { '{ lab_switch = local.config.hyperv.lab_switch }' }
    }

    $args = @"
  source             = "../../modules/$Hypervisor/lab-network"

  lab_name           = "$LabName"
  network_name       = "$NetworkName"
  vlan_id            = $VlanId
  ip_cidr            = "$IpCidr"
  gateway_ip         = "$GatewayIp"
  networking_mode    = "$NetworkingMode"
  hypervisor_config  = $hypervisorConfig
"@

    if ($NetworkingMode -eq 'pfsense') {
        $args += "`n  pfsense_lab_device = local.config.pfsense.lab_device"
    }

    return $args
}

function Get-VmModuleArgs {
    param ([string]$Hypervisor)

    switch ($Hypervisor) {
        'proxmox' {
            return @"
  proxmox_node      = local.config.proxmox.node
  storage_pool      = local.config.proxmox.storage_pool
"@
        }
        'vmware' {
            return @"
  datacenter        = local.config.vmware.datacenter
  cluster           = local.config.vmware.cluster
  datastore         = local.config.vmware.datastore
"@
        }
        'hyperv' {
            return @"
  vhdx_path         = local.config.hyperv.vhdx_path
"@
        }
    }
}

function Get-VmConfigurationEntry {
    param (
        [string]$VmName,
        [hashtable]$VmConfig,
        [string]$LabName,
        [string]$SubnetBase,
        [string]$SubnetMask,
        [string]$GatewayIp,
        [string]$Dc1Ip,
        [string]$Dc2Ip,
        [int]$TemplateVmId
    )

    $v = $VmConfig

    # IP config based on role
    if ($v.role -eq 'dc-primary') {
        $ipConfigBlock = "{ mode = `"static`", address = `"$($v.static_ip)/$SubnetMask`", gateway = `"$GatewayIp`" }"
        $dnsBlock = "[`"8.8.8.8`", `"8.8.4.4`"]"
    }
    elseif ($v.role -eq 'dc-replica') {
        $ipConfigBlock = "{ mode = `"static`", address = `"$($v.static_ip)/$SubnetMask`", gateway = `"$GatewayIp`" }"
        $dnsBlock = "[`"$Dc1Ip`"]"
    }
    else {
        $ipConfigBlock = '{ mode = "dhcp", address = "", gateway = "" }'
        $dnsBlock = "[`"$Dc1Ip`", `"$Dc2Ip`"]"
    }

    # Tags
    $tagList = @("`"$LabName`"")
    switch -Regex ($v.role) {
        '^dc-primary$'  { $tagList += @('"domain-controller"', '"primary"') }
        '^dc-replica$'  { $tagList += @('"domain-controller"', '"replica"') }
        '^sql$'         { $tagList += @('"sql-server"') }
        '^member$'      { $tagList += @('"member-server"') }
        '^workgroup$'   { $tagList += @('"workgroup"') }
    }
    $tagsBlock = "[$(($tagList) -join ', ')]"

    # Description
    $roleDescription = switch -Regex ($v.role) {
        '^dc-primary$' { "Domain Controller (primary)" }
        '^dc-replica$' { "Domain Controller (replica)" }
        '^sql$'        { "SQL Server" }
        '^member$'     { "Member Server" }
        '^workgroup$'  { "Workgroup Server" }
        default        { $v.role }
    }

    # Data disk (SQL only)
    $dataDiskSize = if ($v.role -eq 'sql' -and $null -ne $v['data_disk_size']) { $v.data_disk_size } else { 0 }
    $diskSize = 60

    return @"
    {
      name           = "$VmName"
      role           = "$($v.role)"
      template_id    = "$TemplateVmId"
      cores          = $($v.cores)
      memory         = $($v.memory)
      disk_size      = $diskSize
      data_disk_size = $dataDiskSize
      ip_config      = $ipConfigBlock
      dns_servers    = $dnsBlock
      tags           = $tagsBlock
      description    = "$roleDescription for $LabName"
      on_boot        = false
      cloud_init     = null
    }
"@
}

function Get-OutputsHcl {
    param (
        [string]$LabName,
        [int]$VlanId,
        [string]$IpCidr,
        [string[]]$VmNames
    )

    $hcl = @"
# Lab: $LabName -- Outputs

output "lab_name" {
  value = "$LabName"
}

output "vlan_id" {
  value = $VlanId
}

output "subnet_cidr" {
  value = "$IpCidr"
}

"@

    foreach ($vmName in $VmNames) {
        $hcl += "output `"${vmName}_ip`" {`n"
        $hcl += "  value = module.vms.vms[`"$vmName`"].ip_address`n"
        $hcl += "}`n`n"
    }

    return $hcl
}
