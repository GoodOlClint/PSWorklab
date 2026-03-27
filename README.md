# PSWorklab

PowerShell module for worklab automation -- secrets, config, hypervisor integration, and Terraform/Packer orchestration for lab workflows.

## Requirements

- PowerShell 7.0+
- [Microsoft.PowerShell.SecretManagement](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement) -- vault operations
- [powershell-yaml](https://www.powershellgallery.com/packages/powershell-yaml) -- YAML config parsing
- [PSHcl](https://www.powershellgallery.com/packages/PSHcl) -- HCL parsing and formatting
- [PSProxmoxVE](https://github.com/GoodOlClint/PSProxmoxVE) -- Proxmox API (optional, only needed for Proxmox provider functions)
- [Packer](https://developer.hashicorp.com/packer) -- template image builds
- [Terraform](https://developer.hashicorp.com/terraform) -- infrastructure provisioning

## Installation

```powershell
git clone https://github.com/GoodOlClint/PSWorklab.git
Import-Module ./PSWorklab/src/PSWorklab/PSWorklab.psd1
```

Required modules are installed automatically when the manifest is loaded, or install them manually:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
Install-Module powershell-yaml -Scope CurrentUser
Install-Module PSHcl -Scope CurrentUser
```

## Quick start

The fastest path from zero to a working lab:

```powershell
# 1. Guided server initialization (prerequisites, credentials, host inventory)
Initialize-LabServer -ProjectRoot ~/Source/worklab

# 2. Build foundation templates (VyOS, Ubuntu, Windows) via worklab scripts
#    See worklab project README for Packer build instructions

# 3. Create a lab
New-Lab -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal

# 4. Check for stale templates
Get-StaleTemplate -MaxAgeDays 30
```

## Setup

### Option A: Guided setup (recommended)

```powershell
Initialize-LabServer -ProjectRoot ~/Source/worklab
```

This walks through: prerequisite checks, vault setup, starter config creation, Proxmox API token creation, and host inventory discovery.

### Option B: Manual setup

#### 1. Create a vault

PSWorklab uses the default SecretManagement vault:

```powershell
Register-SecretVault -Name 'MyVault' -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```

Or specify a vault explicitly:

```powershell
Initialize-WorklabContext -ProjectRoot ~/Source/worklab -VaultName 'SpecificVault'
```

#### 2. Configure your project

Create a `worklab-config.yml` in your project root:

```yaml
hypervisor: proxmox
networking_mode: vyos

proxmox:
  api_url: https://pve.local:8006
  api_token_id: root@pam!worklab
  node: pve
  storage_pool: local-lvm
  sdn_zone: worklab
  skip_cert_check: true

vyos:
  api_url: https://10.0.0.2
  trunk_interface: eth1

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
```

#### 3. Set up Proxmox API token

```powershell
Initialize-ProxmoxToken
```

This creates a least-privilege API token, stores the secret in the vault, and writes the token ID back to config.

## Functions

### Server initialization

| Function | Description |
|----------|-------------|
| `Initialize-LabServer` | Guided setup: prerequisites, vault, config, API token, host inventory |
| `Test-LabServerReady` | Quick check that all prerequisites and config are in place |
| `Get-LabServerInventory` | Discover Proxmox host topology (nodes, storage, bridges, VMs, ISOs) |

### Config

| Function | Description |
|----------|-------------|
| `Initialize-WorklabContext` | Set the project root and vault for the session |
| `Get-WorklabConfig` | Load `worklab-config.yml` as a hashtable |
| `Get-ConfigValue` | Read a dot-path value with a default fallback |
| `Set-WorklabConfigValue` | Update a single YAML key in place |

### Secrets

| Function | Description |
|----------|-------------|
| `New-ComplexPassword` | Generate a cryptographically secure password |
| `Get-SecretPath` | Build a vault path following the worklab naming convention |
| `Get-OrCreateSecret` | Retrieve or auto-generate a vault secret |
| `Get-RequiredSecret` | Retrieve a secret that must already exist |
| `Remove-ScopedSecret` | Remove all secrets under a scope/name prefix |
| `Test-VaultReady` | Validate the vault and required user-provisioned secrets |
| `Import-LabSecret` | Load secrets into process environment variables |
| `Remove-LabSecret` | Clear all env vars set by `Import-LabSecret` |

### Secret var files

An alternative to environment variables -- writes secrets to a temporary JSON file that Terraform and Packer consume via `-var-file`.

| Function | Description |
|----------|-------------|
| `New-SecretVarFile` | Write secrets to a temp `.auto.tfvars.json` or `.auto.pkrvars.json` file |
| `Remove-SecretVarFile` | Securely overwrite and delete a secret var file |

### Lab generation

Config-driven Terraform HCL generation. Supports all three hypervisors (proxmox, vmware, hyperv) and both networking modes (vyos, flat).

| Function | Description |
|----------|-------------|
| `New-Lab` | Generate lab config + Terraform files in one step |
| `New-LabConfig` | Build an editable `lab-config.yml` from parameters + product definitions |
| `New-LabTerraform` | Generate `.tf` files from an existing `lab-config.yml` |

```powershell
# One-step: generate everything
New-Lab -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal

# Or two-step: generate config, edit it, then generate HCL
New-LabConfig -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal
# ... edit terraform/labs/lab-03/lab-config.yml (change VM sizes, templates, etc.) ...
New-LabTerraform -LabName lab-03
```

With product definitions:

```powershell
New-Lab -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal `
    -Products @("myproduct:1.0", "another:2.0")
```

### HCL / IaC tooling

| Function | Description |
|----------|-------------|
| `Write-HclFile` | Validate HCL syntax, format via PSHcl round-trip, and write to disk |
| `ConvertTo-PackerVarArgs` | Convert a hashtable to a `-var key=value` argument array for splatting |

### Template registry

Manages `build-info/worklab-templates.yml`, which tracks Packer-built VM templates.

| Function | Description |
|----------|-------------|
| `Get-TemplateRegistry` | Load the template registry as a hashtable |
| `Resolve-TemplateVmId` | Look up a template name to VM ID (or reverse lookup by ID) |
| `Register-Template` | Add or update a template entry after a successful build |
| `Get-StaleTemplate` | Find templates older than a threshold (default 30 days) |

```powershell
# Check which templates need rebuilding
Get-StaleTemplate -MaxAgeDays 30

# Register a template after a Packer build
Register-Template -TemplateName server-2025 -VmId 9001
```

### ISO inspection (Windows-only)

| Function | Description |
|----------|-------------|
| `Get-WindowsIsoInfo` | Mount a Windows Server ISO and return version year + WIM image name |
| `Get-SqlIsoVersion` | Mount a SQL Server ISO and return the release year |

### Providers / Proxmox

| Function | Description |
|----------|-------------|
| `Import-PSProxmoxVE` | Lazy-load the PSProxmoxVE module from installed or dev paths |
| `Connect-WorklabProxmox` | Connect to Proxmox using config and vault credentials |
| `Initialize-ProxmoxToken` | Create a least-privilege API token and store it in the vault |
| `Get-NextProxmoxVmId` | Find the next available VM ID on a Proxmox node |
| `Get-LabServerInventory` | Discover host topology (nodes, storage, bridges, VMs, ISOs, SDN) |

## Networking

PSWorklab generates Terraform HCL for two networking modes:

### VyOS (networking_mode: vyos)

Each lab gets an isolated VLAN with VyOS managing DHCP, firewall rules, and routing. VyOS is deployed via Packer from ISO and managed by the `thomasfinstad/vyos-rolling` Terraform provider (API key authentication).

Lab creation automatically generates HCL that:
- Creates a Proxmox SDN VNet and subnet for the lab VLAN
- Configures VyOS VLAN interface, DHCP server, and firewall rules via Terraform
- Assigns static IPs to domain controllers (.10, .11), DHCP to all other VMs

### Flat (networking_mode: flat)

Labs use Proxmox SDN with built-in dnsmasq DHCP. No firewall appliance. Simpler but no per-lab isolation.

## Secret management patterns

PSWorklab offers two ways to pass secrets to Terraform and Packer:

**Environment variables** (`Import-LabSecret`): Sets `TF_VAR_*` / `PKR_VAR_*` process env vars. Simple, works everywhere.

**Var files** (`New-SecretVarFile`): Writes secrets to a temp JSON file with restrictive permissions, securely wiped on cleanup.

Both track what they create and clean up only what they set.

## Development

### Running tests

```powershell
Invoke-Pester tests/ -Output Detailed
```

### Running the linter

```powershell
Invoke-ScriptAnalyzer -Path src/PSWorklab -Recurse -Settings PSScriptAnalyzerSettings.psd1
```

### Adding a new public function

1. Create `src/PSWorklab/Public/Verb-Noun.ps1` (one function per file, filename = function name)
2. Add the function name to `FunctionsToExport` in `src/PSWorklab/PSWorklab.psd1`
3. Add a test file at `tests/Verb-Noun.Tests.ps1`

The `.psm1` loader dot-sources all `.ps1` files under `Public/` recursively.

### Adding a new hypervisor provider

1. Create functions under `src/PSWorklab/Public/Providers/`
2. Add provider-specific HCL fragments to `src/PSWorklab/Private/HclFragments.ps1`
3. Add cases to the `switch ($hypervisor)` blocks in `Import-LabSecret`, `New-SecretVarFile`, and `HclFragments.ps1`
4. Add function names to `FunctionsToExport` in the manifest

## License

See [LICENSE](LICENSE) for details.
