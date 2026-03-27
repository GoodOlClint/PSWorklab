@{
    RootModule        = 'PSWorklab.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a3f7e8d2-4c91-4b6f-9e3a-1d5c8f2b7a04'
    Author            = 'GoodOlClint'
    Description       = 'PowerShell module for worklab automation -- secrets, config, and hypervisor integration for Packer/Terraform/DSC lab workflows.'

    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')

    RequiredModules   = @(
        'Microsoft.PowerShell.SecretManagement',
        'powershell-yaml',
        'PSHcl'
    )

    FunctionsToExport = @(
        # Config
        'Initialize-WorklabContext',
        'Get-WorklabConfig',
        'Get-ConfigValue',
        'Set-WorklabConfigValue',

        # Secrets
        'New-ComplexPassword',
        'Get-SecretPath',
        'Get-OrCreateSecret',
        'Get-RequiredSecret',
        'Remove-ScopedSecret',
        'Test-VaultReady',
        'Import-LabSecret',
        'Remove-LabSecret',

        # Secret var files (alternative to env vars for Terraform/Packer)
        'New-SecretVarFile',
        'Remove-SecretVarFile',

        # Utility
        'Wait-TcpReady',

        # HCL / IaC tooling
        'Write-HclFile',
        'ConvertTo-PackerVarArgs',

        # Template registry
        'Get-TemplateRegistry',
        'Resolve-TemplateVmId',
        'Register-Template',

        # Lab generation
        'New-Lab',
        'New-LabConfig',
        'New-LabTerraform',

        # ISO inspection (Windows-only)
        'Get-WindowsIsoInfo',
        'Get-SqlIsoVersion',

        # Providers/Proxmox
        'Import-PSProxmoxVE',
        'Connect-WorklabProxmox',
        'Initialize-ProxmoxToken',
        'Get-NextProxmoxVmId'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('worklab', 'proxmox', 'packer', 'terraform', 'lab', 'automation')
            ProjectUri = 'https://github.com/GoodOlClint/PSWorklab'
        }
    }
}
