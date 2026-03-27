function Test-VaultReady {
    <#
    .SYNOPSIS
        Validates that the vault exists and contains required user-provisioned secrets.
    .DESCRIPTION
        Only checks for secrets the user must manually provide (hypervisor credentials).
        All other secrets are auto-generated on demand.
    .PARAMETER IncludeBackend
        Also check for S3-compatible backend secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY).
    .EXAMPLE
        if (-not (Test-VaultReady)) { throw "Vault not configured" }
    .EXAMPLE
        Test-VaultReady -IncludeBackend
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [switch]$IncludeBackend
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
        Write-Host "ERROR: Microsoft.PowerShell.SecretManagement module is not installed." -ForegroundColor Red
        Write-Host "Install it: Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser" -ForegroundColor Yellow
        return $false
    }

    $vault = Get-SecretVault -Name $script:VaultName -ErrorAction SilentlyContinue
    if (-not $vault) {
        Write-Host "ERROR: Vault '$($script:VaultName)' is not registered." -ForegroundColor Red
        Write-Host "Register it:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser" -ForegroundColor Yellow
        Write-Host "  Register-SecretVault -Name '$($script:VaultName)' -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault" -ForegroundColor Yellow
        return $false
    }

    $config = Get-WorklabConfig
    $hypervisor = Get-ConfigValue $config 'hypervisor' 'proxmox'

    $required = @()
    if ($script:HypervisorSecrets.Contains($hypervisor)) {
        $required += $script:HypervisorSecrets[$hypervisor]
    }
    if ($IncludeBackend) {
        $required += $script:BackendSecretNames
    }

    if ($required.Count -eq 0) { return $true }

    $existingSecrets = @((Get-SecretInfo -Vault $script:VaultName).Name)
    $missing = @($required | Where-Object { $_ -notin $existingSecrets })

    if ($missing.Count -gt 0) {
        Write-Host "ERROR: Missing secrets in vault '$($script:VaultName)':" -ForegroundColor Red
        foreach ($m in $missing) {
            Write-Host "  - $m" -ForegroundColor Yellow
        }
        Write-Host "Add them with: Set-Secret -Name '<name>' -Secret '<value>'" -ForegroundColor Yellow
        return $false
    }

    return $true
}
