# PSWorklab

PowerShell module for worklab automation -- secrets, config, and hypervisor integration for Packer/Terraform/DSC lab workflows.

## Requirements

- PowerShell 7.0+
- [Microsoft.PowerShell.SecretManagement](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement) -- vault operations
- [powershell-yaml](https://www.powershellgallery.com/packages/powershell-yaml) -- YAML config parsing
- [PSProxmoxVE](https://github.com/GoodOlClint/PSProxmoxVE) -- Proxmox API (optional, only needed for Proxmox provider functions)

## Installation

### From source

```powershell
git clone https://github.com/GoodOlClint/PSWorklab.git
Import-Module ./PSWorklab/src/PSWorklab/PSWorklab.psd1
```

### Dependencies

Required modules are installed automatically when the manifest is loaded, or install them manually:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
Install-Module powershell-yaml -Scope CurrentUser
```

## Quick start

```powershell
Import-Module PSWorklab -ErrorAction Stop
Initialize-WorklabContext -ProjectRoot ~/Source/worklab

# Load and query config
$config = Get-WorklabConfig
Get-ConfigValue $config 'proxmox.node' 'pve'

# Check vault readiness
Test-VaultReady

# Load secrets as env vars, run a build, then clean up
Import-LabSecret -IncludePacker -TemplateName server-2025
try {
    packer build template.pkr.hcl
}
finally {
    Remove-LabSecret
}
```

## Setup

### 1. Create a vault

```powershell
Register-SecretVault -Name 'WorklabVault' -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```

### 2. Configure your project

Create a `worklab-config.yml` in your project root:

```yaml
hypervisor: proxmox

proxmox:
  api_url: https://pve.local:8006
  api_token_id: root@pam!worklab
  node: pve
  storage: local-lvm
  skip_cert_check: true

networking_mode: pfsense
```

### 3. Set up Proxmox API token

```powershell
Initialize-ProxmoxToken
```

This interactively creates a least-privilege API token on your Proxmox server, stores the secret in the vault, and writes the token ID back to your config file.

## Functions

### Config

| Function | Description |
|----------|-------------|
| `Initialize-WorklabContext` | Set the project root for the session |
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

```powershell
$varFile = New-SecretVarFile -Tool Terraform -LabName lab-03
try {
    terraform plan -var-file="$varFile"
}
finally {
    Remove-SecretVarFile -Path $varFile
}
```

### Utility

| Function | Description |
|----------|-------------|
| `Wait-TcpReady` | Poll a TCP port until it responds or times out (cross-platform) |

### Providers / Proxmox

| Function | Description |
|----------|-------------|
| `Import-PSProxmoxVE` | Lazy-load the PSProxmoxVE module from installed or dev paths |
| `Connect-WorklabProxmox` | Connect to Proxmox using config and vault credentials |
| `Initialize-ProxmoxToken` | Create a least-privilege API token and store it in the vault |

## Secret management patterns

PSWorklab offers two ways to pass secrets to Terraform and Packer:

### Environment variables (Import-LabSecret)

Secrets are set as process-scoped environment variables (`TF_VAR_*`, `PKR_VAR_*`). Simple and works everywhere, but secrets live in the process environment for the duration of the build.

```powershell
Import-LabSecret -IncludePacker -TemplateName server-2025
try { packer build ... }
finally { Remove-LabSecret }
```

### Var files (New-SecretVarFile)

Secrets are written to a temporary JSON file with restrictive file permissions. The file is securely wiped on cleanup. Avoids process-wide env var exposure.

```powershell
$varFile = New-SecretVarFile -Tool Packer -TemplateName server-2025
try { packer build -var-file="$varFile" ... }
finally { Remove-SecretVarFile -Path $varFile }
```

Both patterns track what they create and clean up only what they set -- no hardcoded lists that can go stale.

## Development

### Loading from source

```powershell
Import-Module ~/Source/PSWorklab/src/PSWorklab/PSWorklab.psd1 -Force
Initialize-WorklabContext -ProjectRoot ~/Source/worklab
```

### Running tests

```powershell
Invoke-Pester tests/ -Output Detailed
```

### Running the linter

```powershell
Invoke-ScriptAnalyzer -Path src/PSWorklab -Recurse -Settings PSScriptAnalyzerSettings.psd1
```

### Adding a new public function

1. Create `src/PSWorklab/Public/Verb-Noun.ps1` with the function (one function per file, filename matches function name)
2. Add the function name to `FunctionsToExport` in `src/PSWorklab/PSWorklab.psd1`
3. Add a test file at `tests/Verb-Noun.Tests.ps1`

The `.psm1` loader automatically dot-sources all `.ps1` files under `Public/` recursively, so no loader changes are needed.

### Adding a new hypervisor provider

1. Create `src/PSWorklab/Public/Providers/Connect-WorklabHyperV.ps1` (or similar)
2. Implement connection and credential setup functions
3. Add the function names to `FunctionsToExport` in the manifest
4. Add a case to the `switch ($hypervisor)` block in `Import-LabSecret` and `New-SecretVarFile`

The config-driven dispatch (`Get-ConfigValue $config 'hypervisor'`) already supports this.

## License

See [LICENSE](LICENSE) for details.
