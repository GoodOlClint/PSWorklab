# Module-scoped state -- accessible to all functions in the module, not exported.

$script:VaultName = "WorklabVault"
$script:ProjectRoot = $null  # Set by Initialize-WorklabContext or callers

# User-provisioned secrets per hypervisor
$script:HypervisorSecrets = @{
    proxmox = @("PROXMOX_TOKEN_SECRET")
    hyperv  = @("HYPERV_PASSWORD")
    vmware  = @("VSPHERE_PASSWORD")
}

# S3-compatible Terraform state backend secrets
$script:BackendSecretNames = @(
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY"
)

# Tracks which env vars Import-LabSecrets actually set (for cleanup)
$script:LoadedEnvVars = [System.Collections.Generic.List[string]]::new()
