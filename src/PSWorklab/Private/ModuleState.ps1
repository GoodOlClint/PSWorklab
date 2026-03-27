# Module-scoped state -- accessible to all functions in the module, not exported.

$script:VaultName = $null    # Set by Initialize-WorklabContext (explicit or default vault)
$script:ProjectRoot = $null  # Set by Initialize-WorklabContext or callers
$script:ProxmoxTokenSecretName = "PROXMOX_TOKEN_SECRET"

# User-provisioned secrets per hypervisor
$script:HypervisorSecrets = @{
    proxmox = @($script:ProxmoxTokenSecretName)
    hyperv  = @("HYPERV_PASSWORD")
    vmware  = @("VSPHERE_PASSWORD")
}

# S3-compatible Terraform state backend secrets
$script:BackendSecretNames = @(
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY"
)

# Tracks which env vars Import-LabSecret actually set (for cleanup)
$script:LoadedEnvVars = [System.Collections.Generic.List[string]]::new()
