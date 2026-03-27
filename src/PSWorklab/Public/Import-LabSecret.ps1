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
    .PARAMETER IncludeBackend
        Also load S3-compatible backend secrets as env vars.
    .PARAMETER IncludePacker
        Set PKR_VAR_* environment variables for Packer builds.
    .PARAMETER TemplateName
        Template name for looking up the admin password secret.
    .PARAMETER LabName
        Lab name for looking up lab-specific secrets (e.g., VyOS API key).
    .EXAMPLE
        Import-LabSecret -IncludePacker -TemplateName server-2025
    .EXAMPLE
        Import-LabSecret -LabName lab-03 -IncludeBackend
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
    $networkingMode = Get-ConfigValue $config 'networking_mode' 'vyos'

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

    if ($LabName -and $networkingMode -eq 'vyos') {
        $vyosApiKey = Get-RequiredSecret -Path "VYOS_API_KEY"
        Set-TrackedEnvVar -Name "TF_VAR_vyos_api_key" -Value $vyosApiKey
    }

    if ($IncludeBackend) {
        foreach ($name in $script:BackendSecretNames) {
            $value = Get-Secret -Vault $script:VaultName -Name $name -AsPlainText -ErrorAction Stop
            Set-TrackedEnvVar -Name $name -Value $value
        }
    }

    Write-Host "Loaded $($script:LoadedEnvVars.Count) env vars ($hypervisor/$networkingMode)." -ForegroundColor DarkGray
}
