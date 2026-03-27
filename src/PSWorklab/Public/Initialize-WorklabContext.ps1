function Initialize-WorklabContext {
    <#
    .SYNOPSIS
        Sets the project root and vault for this session. Call once at the top of each script.
    .DESCRIPTION
        All config/secret functions use the project root to locate worklab-config.yml
        and other project files. Vault functions use the vault name to target the
        correct SecretManagement vault.

        If -VaultName is not specified, the default SecretManagement vault is used.
        If no default vault is registered, an error is thrown with setup instructions.
    .PARAMETER ProjectRoot
        Path to the worklab project root (contains worklab-config.yml).
    .PARAMETER VaultName
        Name of the SecretManagement vault to use. If omitted, uses the default vault.
    .EXAMPLE
        Initialize-WorklabContext -ProjectRoot (Split-Path $PSScriptRoot)
    .EXAMPLE
        Initialize-WorklabContext -ProjectRoot ~/Source/worklab -VaultName MyVault
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$ProjectRoot,

        [string]$VaultName
    )

    $script:ProjectRoot = $ProjectRoot

    if ($VaultName) {
        $vault = Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue
        if (-not $vault) {
            throw "Vault '$VaultName' is not registered. Register it with Register-SecretVault."
        }
        $script:VaultName = $VaultName
    }
    else {
        $defaultVault = Get-SecretVault -ErrorAction SilentlyContinue | Where-Object { $_.IsDefault } | Select-Object -First 1
        if (-not $defaultVault) {
            throw @"
No default SecretManagement vault found. Either:
  - Register a default vault: Register-SecretVault -Name 'MyVault' -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
  - Or specify one explicitly: Initialize-WorklabContext -ProjectRoot ... -VaultName 'MyVault'
"@
        }
        $script:VaultName = $defaultVault.Name
    }
}
