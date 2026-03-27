function New-ComplexPassword {
    <#
    .SYNOPSIS
        Generates a cryptographically secure password meeting Windows/SQL complexity.
    .DESCRIPTION
        Uses System.Security.Cryptography.RandomNumberGenerator.
        Guarantees at least 1 uppercase, 1 lowercase, 1 digit, 1 symbol.
        Avoids shell-hostile characters: ` $ " ' < > & \ { }
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param (
        [ValidateRange(12, 128)]
        [int]$Length = 24
    )

    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower   = 'abcdefghjkmnpqrstuvwxyz'
    $digits  = '23456789'
    $symbols = '!@#%^*()-_=+[];:,.?~'
    $all     = $upper + $lower + $digits + $symbols

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        # Unbiased random index: reject values that would cause modulo bias
        $pickRandom = {
            param ([string]$CharSet)
            $len = $CharSet.Length
            $limit = 256 - (256 % $len)
            do {
                $bytes = [byte[]]::new(1)
                $rng.GetBytes($bytes)
            } while ($bytes[0] -ge $limit)
            return $CharSet[$bytes[0] % $len]
        }

        # Guarantee one of each class
        $chars = [System.Collections.Generic.List[char]]::new()
        $chars.Add((&$pickRandom $upper))
        $chars.Add((&$pickRandom $lower))
        $chars.Add((&$pickRandom $digits))
        $chars.Add((&$pickRandom $symbols))

        for ($i = 4; $i -lt $Length; $i++) {
            $chars.Add((&$pickRandom $all))
        }

        # Fisher-Yates shuffle (4 bytes per index for negligible bias on small arrays)
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $buf = [byte[]]::new(4)
            $rng.GetBytes($buf)
            $j = [System.Math]::Abs([System.BitConverter]::ToInt32($buf, 0)) % ($i + 1)
            $temp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $temp
        }
    }
    finally {
        $rng.Dispose()
    }

    return -join $chars
}

function Get-SecretPath {
    <#
    .SYNOPSIS
        Returns the vault secret name following the worklab naming convention.
    .EXAMPLE
        Get-SecretPath -Scope template -Name server-2025 -Key admin_password
        # Returns: worklab/template/server-2025/admin_password
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('template', 'foundation', 'lab')]
        [string]$Scope,

        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($Scope -ne 'foundation' -and -not $Name) {
        throw "Get-SecretPath: -Name is required for scope '$Scope'."
    }

    if ($Name) { return "worklab/$Scope/$Name/$Key" }
    return "worklab/$Scope/$Key"
}

function Get-OrCreateSecret {
    <#
    .SYNOPSIS
        Retrieves a secret from the vault, creating it if it doesn't exist.
    .DESCRIPTION
        Idempotent: returns the existing value if present, generates and
        stores a new password if missing (or if -Force is specified).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateRange(12, 128)]
        [int]$Length = 24,

        [switch]$Force
    )

    if (-not $Force) {
        $existing = Get-SecretInfo -Vault $script:VaultName -Name $Path -ErrorAction SilentlyContinue
        if ($existing) {
            $value = Get-Secret -Vault $script:VaultName -Name $Path -AsPlainText -ErrorAction Stop
            Write-Host "  Retrieved secret: $Path" -ForegroundColor DarkGray
            return $value
        }
    }

    if ($PSCmdlet.ShouldProcess("Secret '$Path' in vault '$($script:VaultName)'", "Generate and store new secret")) {
        $password = New-ComplexPassword -Length $Length
        Set-Secret -Vault $script:VaultName -Name $Path -Secret $password -ErrorAction Stop
        Write-Host "  Generated secret: $Path" -ForegroundColor DarkGray
        return $password
    }
}

function Get-RequiredSecret {
    <#
    .SYNOPSIS
        Retrieves a secret that must already exist in the vault. Throws if missing.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $existing = Get-SecretInfo -Vault $script:VaultName -Name $Path -ErrorAction SilentlyContinue
    if (-not $existing) {
        throw "Required secret '$Path' not found in vault '$($script:VaultName)'. Was the prerequisite step completed?"
    }

    return Get-Secret -Vault $script:VaultName -Name $Path -AsPlainText -ErrorAction Stop
}

function Remove-ScopedSecret {
    <#
    .SYNOPSIS
        Removes all vault secrets matching a scope/name prefix.
    .EXAMPLE
        Remove-ScopedSecret -Scope lab -Name lab-03
        # Removes all secrets matching worklab/lab/lab-03/*
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('template', 'foundation', 'lab')]
        [string]$Scope,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $prefix = "worklab/$Scope/$Name/"
    $secrets = @(Get-SecretInfo -Vault $script:VaultName -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$prefix*" })

    foreach ($s in $secrets) {
        if ($PSCmdlet.ShouldProcess($s.Name, "Remove secret from $($script:VaultName)")) {
            Remove-Secret -Vault $script:VaultName -Name $s.Name -ErrorAction SilentlyContinue
            Write-Host "  Removed secret: $($s.Name)" -ForegroundColor DarkGray
        }
    }

    return $secrets.Count
}

function Test-VaultReady {
    <#
    .SYNOPSIS
        Validates that the vault exists and contains required user-provisioned secrets.
    .DESCRIPTION
        Only checks for secrets the user must manually provide (hypervisor credentials).
        All other secrets are auto-generated on demand.
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

function Import-LabSecret {
    <#
    .SYNOPSIS
        Loads secrets from the vault and sets tool-specific environment variables.
    .DESCRIPTION
        Tracks which env vars are set so Remove-LabSecret can clean up exactly
        what was loaded (no stale hardcoded list).

        Callers should wrap usage in try/finally to ensure Remove-LabSecret
        runs even on failure:

            Import-LabSecret -IncludePacker -TemplateName $name
            try { packer build ... }
            finally { Remove-LabSecret }
    #>
    [CmdletBinding()]
    param (
        [switch]$IncludeBackend,
        [switch]$IncludePacker,
        [string]$TemplateName,
        [string]$LabName
    )

    $config = Get-WorklabConfig -RequiredFields @('hypervisor')
    $hypervisor = Get-ConfigValue $config 'hypervisor' 'proxmox'
    $networkingMode = Get-ConfigValue $config 'networking_mode' 'pfsense'

    switch ($hypervisor) {
        'proxmox' {
            $tokenSecret = Get-Secret -Vault $script:VaultName -Name $script:ProxmoxTokenSecretName -AsPlainText -ErrorAction Stop
            Set-TrackedEnvVar -Name $script:ProxmoxTokenSecretName -Value $tokenSecret

            $tokenId = Get-ConfigValue $config 'proxmox.api_token_id'
            if (-not $tokenId) {
                throw "Config field 'proxmox.api_token_id' is required for secret loading. Run Initialize-ProxmoxToken first."
            }
            Set-TrackedEnvVar -Name "TF_VAR_proxmox_api_token" -Value "$tokenId=$tokenSecret"

            if ($IncludePacker) {
                Set-TrackedEnvVar -Name "PKR_VAR_proxmox_api_token_secret" -Value $tokenSecret
            }
        }
        default {
            Write-Warning "No secret-loading logic implemented for hypervisor '$hypervisor'. Only env vars common to all hypervisors will be set."
        }
    }

    if ($IncludePacker -and $TemplateName) {
        $tplPath = Get-SecretPath -Scope template -Name $TemplateName -Key admin_password
        $adminPassword = Get-OrCreateSecret -Path $tplPath
        Set-TrackedEnvVar -Name "PKR_VAR_winrm_password" -Value $adminPassword
    }

    if ($LabName -and $networkingMode -eq 'pfsense') {
        $pfsPath = Get-SecretPath -Scope foundation -Key pfsense_password
        $pfsPassword = Get-RequiredSecret -Path $pfsPath
        Set-TrackedEnvVar -Name "TF_VAR_pfsense_password" -Value $pfsPassword
    }

    if ($IncludeBackend) {
        foreach ($name in $script:BackendSecretNames) {
            $value = Get-Secret -Vault $script:VaultName -Name $name -AsPlainText -ErrorAction Stop
            Set-TrackedEnvVar -Name $name -Value $value
        }
    }

    Write-Host "Loaded $($script:LoadedEnvVars.Count) env vars ($hypervisor/$networkingMode)." -ForegroundColor DarkGray
}

function Remove-LabSecret {
    <#
    .SYNOPSIS
        Removes all secret environment variables set by Import-LabSecret.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    if ($PSCmdlet.ShouldProcess("$($script:LoadedEnvVars.Count) env vars", "Clear secret environment variables")) {
        foreach ($name in $script:LoadedEnvVars) {
            [System.Environment]::SetEnvironmentVariable($name, $null, "Process")
        }
        $script:LoadedEnvVars.Clear()
    }
}
