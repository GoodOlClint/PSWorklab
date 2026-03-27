function Connect-WorklabProxmox {
    <#
    .SYNOPSIS
        Establishes a PSProxmoxVE session using worklab config and vault credentials.
    .DESCRIPTION
        Reads connection details from worklab-config.yml and the API token from
        the vault, then connects to the Proxmox server.
    .EXAMPLE
        $session = Connect-WorklabProxmox
    .OUTPUTS
        The PveSession object (also set as the active session in PSProxmoxVE module state).
    #>
    [CmdletBinding()]
    param ()

    Import-PSProxmoxVE

    $config = Get-WorklabConfig -RequiredFields @('proxmox.api_url', 'proxmox.api_token_id')
    $tokenSecret = Get-Secret -Vault $script:VaultName -Name $script:ProxmoxTokenSecretName -AsPlainText -ErrorAction Stop
    $tokenId = $config.proxmox.api_token_id
    $fullToken = "$tokenId=$tokenSecret"

    $uri = [System.Uri]::new($config.proxmox.api_url)
    $server = $uri.Host
    $port = if ($uri.Port -gt 0) { $uri.Port } else { 8006 }
    $skipCert = (Get-ConfigValue $config 'proxmox.skip_cert_check' $true) -eq $true

    $connectParams = @{
        Server    = $server
        Port      = $port
        ApiToken  = $fullToken
        PassThru  = $true
    }
    if ($skipCert) { $connectParams.SkipCertificateCheck = $true }

    $session = Connect-PveServer @connectParams
    Write-Host "  Connected to Proxmox: ${server}:${port}" -ForegroundColor DarkGray
    return $session
}
