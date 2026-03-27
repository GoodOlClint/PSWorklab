function Initialize-ProxmoxToken {
    <#
    .SYNOPSIS
        Prompts for Proxmox credentials and creates an API token with the required permissions.
    .DESCRIPTION
        Connects to Proxmox using username/password, creates a custom role with exactly
        the privileges worklab needs, generates an API token with privilege separation,
        grants the role to the token, and stores the result in the vault and config.

        The user's password is never stored -- only the generated token secret.
        Idempotent: skips role/token creation if they already exist. Use -Force to
        regenerate the token (deletes and recreates).
    .PARAMETER Credential
        Proxmox credentials. Prompted interactively if not supplied.
    .PARAMETER Force
        Delete and recreate the token if it already exists.
    .EXAMPLE
        Initialize-ProxmoxToken
    .EXAMPLE
        Initialize-ProxmoxToken -Credential (Get-Credential root@pam) -Force
    .OUTPUTS
        The API token ID string (e.g. "root@pam!worklab").
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [Parameter(HelpMessage = "Proxmox credentials (prompted if not supplied).")]
        [PSCredential]$Credential,

        [Parameter(HelpMessage = "Delete and recreate the token if it already exists.")]
        [switch]$Force
    )

    Import-PSProxmoxVE

    $config = Get-WorklabConfig -RequiredFields @('proxmox.api_url')

    $uri = [System.Uri]::new($config.proxmox.api_url)
    $server = $uri.Host
    $port = if ($uri.Port -gt 0) { $uri.Port } else { 8006 }
    $skipCert = (Get-ConfigValue $config 'proxmox.skip_cert_check' $true) -eq $true

    # Prompt for credentials if not supplied
    if (-not $Credential) {
        Write-Host ""
        Write-Host "Proxmox API token setup" -ForegroundColor Cyan
        Write-Host "Enter credentials for your Proxmox server ($server)."
        Write-Host "Username must include the realm, e.g. root@pam" -ForegroundColor DarkGray
        $Credential = Get-Credential -Message "Proxmox credentials (e.g. root@pam)"
    }

    $userId = $Credential.UserName
    $tokenName = "worklab"
    $roleName = "worklab-automation"
    $fullTokenId = "$userId!$tokenName"

    $connectParams = @{
        Server     = $server
        Port       = $port
        Credential = $Credential
    }
    if ($skipCert) { $connectParams.SkipCertificateCheck = $true }

    Write-Host "  Connecting to Proxmox as $userId..." -ForegroundColor DarkGray
    Connect-PveServer @connectParams | Out-Null

    # --- Create role ---
    $privileges = @(
        "VM.Allocate", "VM.Clone", "VM.Config.Disk", "VM.Config.CPU",
        "VM.Config.Memory", "VM.Config.Network", "VM.Config.Options",
        "VM.Config.CDROM", "VM.Config.Cloudinit", "VM.Audit",
        "VM.PowerMgmt", "VM.Console",
        "Datastore.Allocate", "Datastore.AllocateSpace",
        "Datastore.AllocateTemplate", "Datastore.Audit",
        "SDN.Use", "SDN.Allocate", "SDN.Audit",
        "Sys.Audit", "Sys.Modify"
    ) -join ","

    $existingRole = Get-PveRole | Where-Object { $_.RoleId -eq $roleName }
    if (-not $existingRole) {
        if ($PSCmdlet.ShouldProcess("Proxmox role '$roleName'", "Create role with worklab privileges")) {
            Write-Host "  Creating role: $roleName" -ForegroundColor DarkGray
            New-PveRole -RoleId $roleName -Privileges $privileges
        }
    }
    else {
        Write-Host "  Role already exists: $roleName" -ForegroundColor DarkGray
    }

    # --- Create token ---
    # FullTokenId is not populated by the API (PSProxmoxVE#44) -- match on TokenId
    $existingToken = Get-PveApiToken -UserId $userId | Where-Object { $_.TokenId -eq $tokenName }

    if ($existingToken -and $Force) {
        if ($PSCmdlet.ShouldProcess("Proxmox API token '$fullTokenId'", "Remove existing token")) {
            Write-Host "  Removing existing token: $fullTokenId" -ForegroundColor Yellow
            Remove-PveApiToken -UserId $userId -TokenId $tokenName -Confirm:$false
            $existingToken = $null
        }
    }

    if ($existingToken) {
        Write-Host "  Token already exists: $fullTokenId (use -Force to regenerate)" -ForegroundColor DarkGray
        Set-WorklabConfigValue -Section proxmox -Key api_token_id -Value $fullTokenId

        $vaultEntry = Get-SecretInfo -Vault $script:VaultName -Name $script:ProxmoxTokenSecretName -ErrorAction SilentlyContinue
        if (-not $vaultEntry) {
            Write-Host "  WARNING: Token exists in Proxmox but secret is not in the vault." -ForegroundColor Yellow
            Write-Host "  Use -Force to regenerate, or manually add the token secret:" -ForegroundColor Yellow
            Write-Host "    Set-Secret -Name 'PROXMOX_TOKEN_SECRET' -Secret '<token-value>'" -ForegroundColor Yellow
        }

        return $fullTokenId
    }

    if ($PSCmdlet.ShouldProcess("Proxmox API token '$fullTokenId'", "Create token, grant role, and store in vault")) {
        Write-Host "  Creating API token: $fullTokenId" -ForegroundColor DarkGray
        $token = New-PveApiToken -UserId $userId -TokenId $tokenName `
            -Comment "Worklab automation token (Packer, Terraform, scripts)" `
            -PrivilegeSeparation

        # --- Grant role to token ---
        Write-Host "  Granting $roleName to $fullTokenId at /" -ForegroundColor DarkGray
        Set-PvePermission -Path "/" -UgId $fullTokenId -Role $roleName -Propagate

        # --- Store in vault and config ---
        Set-Secret -Vault $script:VaultName -Name $script:ProxmoxTokenSecretName -Secret $token.Value -ErrorAction Stop
        Write-Host "  Stored token secret in vault as $($script:ProxmoxTokenSecretName)" -ForegroundColor Green

        Set-WorklabConfigValue -Section proxmox -Key api_token_id -Value $fullTokenId

        # --- Verify ---
        Write-Host "  Verifying token authentication..." -ForegroundColor DarkGray
        $fullApiToken = "$fullTokenId=$($token.Value)"
        $verifyParams = @{
            Server   = $server
            Port     = $port
            ApiToken = $fullApiToken
        }
        if ($skipCert) { $verifyParams.SkipCertificateCheck = $true }
        Connect-PveServer @verifyParams | Out-Null
        Write-Host "  Token verified successfully." -ForegroundColor Green

        return $fullTokenId
    }
}
