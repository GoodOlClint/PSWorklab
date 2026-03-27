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
    $networkingMode = Get-ConfigValue $config 'networking_mode' 'pfsense'

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

    if ($Tool -eq 'Terraform' -and $LabName -and $networkingMode -eq 'pfsense') {
        $pfsPath = Get-SecretPath -Scope foundation -Key pfsense_password
        $vars['pfsense_password'] = Get-RequiredSecret -Path $pfsPath
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

function Remove-SecretVarFile {
    <#
    .SYNOPSIS
        Securely removes a secret var file created by New-SecretVarFile.
    .DESCRIPTION
        Overwrites the file contents before deletion to reduce the window where
        secrets are recoverable from disk. Safe to call if the file does not exist.
    .EXAMPLE
        Remove-SecretVarFile -Path $varFile
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return }

    if ($PSCmdlet.ShouldProcess($Path, "Remove secret var file")) {
        # Overwrite with zeros before deleting
        $length = (Get-Item $Path).Length
        if ($length -gt 0) {
            $zeros = [byte[]]::new([Math]::Min($length, 4096))
            [System.IO.File]::WriteAllBytes($Path, $zeros)
        }
        Remove-Item -Path $Path -Force
        Write-Host "  Removed secret var file: $Path" -ForegroundColor DarkGray
    }
}
