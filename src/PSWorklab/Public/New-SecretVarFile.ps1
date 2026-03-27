function New-SecretVarFile {
    <#
    .SYNOPSIS
        Writes secrets to a temporary Terraform or Packer variable file.
    .DESCRIPTION
        Creates a JSON var file containing secrets pulled from the vault. The file
        is written with restrictive permissions (owner-only on Unix, ACL-restricted
        on Windows) and should be removed with Remove-SecretVarFile in a finally block.

        This is an alternative to Import-LabSecret for callers that prefer not to
        set secrets as process-wide environment variables. Terraform and Packer both
        support -var-file arguments natively.

        The returned path should be passed as:
          terraform plan -var-file="$varFile"
          packer build -var-file="$varFile"
    .PARAMETER Tool
        Which tool the var file is for: Terraform or Packer.
    .PARAMETER TemplateName
        Template name for looking up the admin password (Packer only).
    .PARAMETER LabName
        Lab name for looking up lab-specific secrets (Terraform only).
    .PARAMETER IncludeBackend
        Also include S3-compatible backend secrets (Terraform only).
    .EXAMPLE
        $varFile = New-SecretVarFile -Tool Terraform -LabName lab-03
        try {
            terraform plan -var-file="$varFile"
        }
        finally {
            Remove-SecretVarFile -Path $varFile
        }
    .OUTPUTS
        System.String -- the full path to the generated var file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Terraform', 'Packer')]
        [string]$Tool,

        [string]$TemplateName,
        [string]$LabName,
        [switch]$IncludeBackend
    )

    $config = Get-WorklabConfig -RequiredFields @('hypervisor')
    $hypervisor = Get-ConfigValue $config 'hypervisor' 'proxmox'
    $networkingMode = Get-ConfigValue $config 'networking_mode' 'vyos'

    $vars = @{}

    switch ($hypervisor) {
        'proxmox' {
            $tokenSecret = Get-Secret -Vault $script:VaultName -Name $script:ProxmoxTokenSecretName -AsPlainText -ErrorAction Stop
            $tokenId = Get-ConfigValue $config 'proxmox.api_token_id'
            if (-not $tokenId) {
                throw "Config field 'proxmox.api_token_id' is required. Run Initialize-ProxmoxToken first."
            }

            switch ($Tool) {
                'Terraform' {
                    $vars['proxmox_api_token'] = "$tokenId=$tokenSecret"
                }
                'Packer' {
                    $vars['proxmox_api_token_secret'] = $tokenSecret
                }
            }
        }
        default {
            Write-Warning "No secret-loading logic implemented for hypervisor '$hypervisor'."
        }
    }

    if ($Tool -eq 'Packer' -and $TemplateName) {
        $tplPath = Get-SecretPath -Scope template -Name $TemplateName -Key admin_password
        $vars['winrm_password'] = Get-OrCreateSecret -Path $tplPath
    }

    if ($Tool -eq 'Terraform' -and $LabName -and $networkingMode -eq 'vyos') {
        $vars['vyos_api_key'] = Get-RequiredSecret -Path "VYOS_API_KEY"
    }

    if ($IncludeBackend -and $Tool -eq 'Terraform') {
        foreach ($name in $script:BackendSecretNames) {
            $value = Get-Secret -Vault $script:VaultName -Name $name -AsPlainText -ErrorAction Stop
            $vars[$name] = $value
        }
    }

    if ($vars.Count -eq 0) {
        throw "No secrets to write for $Tool ($hypervisor). Check parameters."
    }

    # Write to a temp file with a tool-appropriate extension
    $extension = switch ($Tool) {
        'Terraform' { '.auto.tfvars.json' }
        'Packer'    { '.auto.pkrvars.json' }
    }
    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "worklab-secrets-$(Get-Random)$extension"

    if ($PSCmdlet.ShouldProcess($tempFile, "Write $($vars.Count) secrets to $Tool var file")) {
        $vars | ConvertTo-Json -Depth 1 | Set-Content -Path $tempFile -Encoding UTF8 -Force

        # Restrict file permissions to owner only
        if ($IsLinux -or $IsMacOS) {
            chmod 600 $tempFile
        }
        else {
            $acl = Get-Acl -Path $tempFile
            $acl.SetAccessRuleProtection($true, $false)
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                'FullControl', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -Path $tempFile -AclObject $acl
        }

        Write-Host "  Wrote $($vars.Count) secrets to $tempFile ($Tool)" -ForegroundColor DarkGray
        return $tempFile
    }
}
