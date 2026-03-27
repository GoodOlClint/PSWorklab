# PSWorklab Module

PowerShell module extracted from the `worklab` project's `scripts/SecretHelpers.ps1`. Provides config loading, secret management, hypervisor integration, and utility functions used by worklab orchestration scripts.

## Project Structure

```
PSWorklab/
  src/PSWorklab/
    PSWorklab.psd1                # Module manifest (exports, dependencies)
    PSWorklab.psm1                # Loader -- dot-sources Private/ then Public/**
    Private/
      ModuleState.ps1             # Module-scoped variables ($script:VaultName, etc.)
      Set-TrackedEnvVar.ps1       # Internal helper for Import-LabSecret env var tracking
    Public/
      Initialize-WorklabContext.ps1
      Get-WorklabConfig.ps1
      Get-ConfigValue.ps1
      Set-WorklabConfigValue.ps1
      New-ComplexPassword.ps1
      Get-SecretPath.ps1
      Get-OrCreateSecret.ps1
      Get-RequiredSecret.ps1
      Remove-ScopedSecret.ps1
      Test-VaultReady.ps1
      Import-LabSecret.ps1
      Remove-LabSecret.ps1
      New-SecretVarFile.ps1
      Remove-SecretVarFile.ps1
      Wait-TcpReady.ps1
      Import-PSHcl.ps1
      Write-HclFile.ps1
      ConvertTo-PackerVarArgs.ps1
      Providers/
        Import-PSProxmoxVE.ps1
        Connect-WorklabProxmox.ps1
        Initialize-ProxmoxToken.ps1
```

## How It Works

1. Caller does `Import-Module PSWorklab` then `Initialize-WorklabContext -ProjectRoot <path>` to set the project root.
2. All functions use `$script:ProjectRoot` to locate `worklab-config.yml`.
3. Secrets are stored in a SecretManagement vault named `WorklabVault` (configurable via `$script:VaultName` in ModuleState).
4. Hypervisor-specific functions live under `Public/Providers/`. Currently only Proxmox is implemented.

## Consumer: worklab Project

This module is consumed by `~/Source/worklab`. The scripts there (`Build-Template.ps1`, `Build-Foundation.ps1`, `Spinup.ps1`, `New-Lab.ps1`, `Upload-Iso.ps1`) need to be updated to replace `. "$PSScriptRoot\SecretHelpers.ps1"` with:

```powershell
Import-Module PSWorklab -ErrorAction Stop
Initialize-WorklabContext -ProjectRoot (Split-Path $PSScriptRoot)
```

### Mapping from old SecretHelpers.ps1 to new module

All functions kept the same names except:
- `Save-WorklabConfig` -> `Set-WorklabConfigValue` (already renamed in worklab)
- NEW: `Initialize-WorklabContext` (replaces `$script:ProjectRoot = Split-Path -Parent $PSScriptRoot`)
- NEW: `Get-ConfigValue` (replaces `if ($config.Contains('x')) { $config.x } else { 'default' }`)
- NEW: `Wait-TcpReady` (extracted from Build-Foundation.ps1, replaces both `Wait-TcpPort` and `Wait-ForWinRM` in worklab scripts)

### Key improvement: env var tracking

`Import-LabSecret` now tracks which env vars it sets in `$script:LoadedEnvVars`. `Remove-LabSecret` clears exactly those -- no more hardcoded `$AllEnvVarNames` list that could go stale.

## Dependencies

- `Microsoft.PowerShell.SecretManagement` -- vault operations
- `powershell-yaml` -- YAML config parsing
- `PSProxmoxVE` -- Proxmox API (optional, only needed for Proxmox provider functions)
- `PSHcl` -- HCL parsing/formatting (optional, only needed for Write-HclFile)

PSProxmoxVE and PSHcl are NOT RequiredModules in the manifest since they're only needed for specific features. `Import-PSProxmoxVE` and `Import-PSHcl` handle lazy loading.

## Known PSProxmoxVE Issues

These are tracked on https://github.com/GoodOlClint/PSProxmoxVE:
- **#43** (FIXED): `Set-PvePermission` needs token ACL support -- auto-detects `!` in UgId
- **#44**: `Get-PveApiToken` -- `FullTokenId` property is never populated (we filter on `TokenId` instead)
- **#45** (FIXED): `Connect-PveServer` returns session by default now (we still use `-PassThru` for clarity)
- **PVE9**: `VM.Monitor` privilege was removed -- not included in our role definition

## Remaining Work

### Must do (to complete the extraction from worklab)

1. **Update worklab scripts** to `Import-Module PSWorklab` instead of dot-sourcing SecretHelpers.ps1.
   - Replace `. "$PSScriptRoot\SecretHelpers.ps1"` with `Import-Module PSWorklab -ErrorAction Stop` + `Initialize-WorklabContext -ProjectRoot (Split-Path $PSScriptRoot)`
   - Replace `$script:VaultName` references with direct function calls (they're internal now)
   - Replace inline `if ($config.Contains('x')) { $config.x } else { 'default' }` patterns with `Get-ConfigValue`
   - Replace `Wait-TcpPort` in Build-Foundation.ps1 with `Wait-TcpReady`
   - Replace `Wait-ForWinRM` in Spinup.ps1 with `Wait-TcpReady -Port 5986`
   - Delete `scripts/SecretHelpers.ps1` from worklab once all scripts are updated

2. **Extract template registry functions** from Build-Template.ps1 into this module:
   - `Resolve-TemplateVmId` -- lookup template name -> VM ID from `worklab-templates.yml`
   - `Register-Template` -- add/update entry in the registry
   - `Get-NextVmId` -- allocate next available VM ID >= 9000 from Proxmox
   - These are duplicated 4x across Build-Template.ps1 and New-Lab.ps1

3. **Add try/finally to Build-Foundation.ps1** -- secrets are loaded but never cleaned up on failure (Build-Template and Spinup already have this pattern)

### Should do (quality improvements)

4. **~~Extract Packer var builder~~** -- DONE: `ConvertTo-PackerVarArgs` converts a hashtable to `-var key=value` argument arrays. Worklab scripts still need to be updated to use it.

5. **Extract ISO inspection functions** from Build-Template.ps1:
   - `Get-WindowsIsoInfo` -- mount ISO, read WIM edition info (Windows-only)
   - `Get-SqlIsoVersion` -- mount ISO, read setup.exe version (Windows-only)

6. **Set-WorklabConfigValue robustness** -- currently uses line-by-line scan for direct children of top-level sections. This works for all current use cases but document the limitation clearly. Consider adding validation that the key was actually a direct child.

### Future: provider pattern for Hyper-V and VMware

The `Public/Providers/` directory is designed to be extensible. To add a new hypervisor:

1. Create `Public/Providers/HyperV.ps1` (or `VMware.ps1`)
2. Implement the equivalent of:
   - `Connect-WorklabHyperV` -- establish a session
   - `Initialize-HyperVCredentials` -- store credentials in vault
3. Add functions to the `FunctionsToExport` list in `PSWorklab.psd1`
4. Update `Import-LabSecret` switch statement (currently only handles 'proxmox')

The config-driven dispatch (`Get-ConfigValue $config 'hypervisor'`) already supports this -- scripts just need to switch on the hypervisor value.

## Development

```powershell
# Load the module from source
Import-Module ~/Source/PSWorklab/src/PSWorklab/PSWorklab.psd1 -Force

# Set the project root to the worklab checkout
Initialize-WorklabContext -ProjectRoot ~/Source/worklab

# Test config loading
$config = Get-WorklabConfig
Get-ConfigValue $config 'proxmox.node' 'default-value'

# Test Proxmox connection
Import-LabSecret -IncludePacker
Connect-WorklabProxmox
Remove-LabSecret
```

## Code Style

- PowerShell 7+ only (no Windows PowerShell 5.1 compatibility needed)
- Use `[CmdletBinding()]` on all functions
- Use `$script:` for module-scoped state (in ModuleState.ps1 only)
- Use `Write-Host` for user-facing status messages (DarkGray for routine, Green for success, Yellow for warnings, Red for errors, Cyan for headers)
- Prefer `throw` for fatal errors over `Write-Host + exit 1`
- No emojis in output or code
- Cross-platform: avoid Windows-only cmdlets (Test-NetConnection, Get-WindowsImage) in core module functions. Windows-only helpers should be clearly documented as such.
