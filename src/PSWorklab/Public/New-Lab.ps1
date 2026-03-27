function New-Lab {
    <#
    .SYNOPSIS
        Creates a new lab by generating both the config and Terraform files.
    .DESCRIPTION
        Orchestrates the full lab creation workflow:
        1. Generates lab-config.yml from parameters and product definitions (New-LabConfig)
        2. Generates Terraform files from the config (New-LabTerraform)

        For a two-step workflow (generate config, edit, then generate HCL), use
        New-LabConfig and New-LabTerraform separately.
    .PARAMETER LabName
        Lab name (e.g., lab-03).
    .PARAMETER VlanId
        VLAN ID for the lab network (100-999).
    .PARAMETER IpCidr
        IP CIDR for the lab subnet (e.g., 10.103.0.0/24).
    .PARAMETER Domain
        Active Directory domain name (e.g., lab03.internal).
    .PARAMETER Products
        Array of product specs in "name:version" format. Optional.
    .PARAMETER OutputPath
        Directory to write all generated files. Defaults to terraform/labs/$LabName/.
    .PARAMETER Force
        Overwrite existing lab directory without confirmation.
    .EXAMPLE
        New-Lab -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal
    .EXAMPLE
        New-Lab -LabName lab-03 -VlanId 103 -IpCidr 10.103.0.0/24 -Domain lab03.internal -Products @("myproduct:1.0")
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$LabName,

        [Parameter(Mandatory)]
        [ValidateRange(100, 999)]
        [int]$VlanId,

        [Parameter(Mandatory)]
        [ValidatePattern('^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$')]
        [string]$IpCidr,

        [Parameter(Mandatory)]
        [string]$Domain,

        [string[]]$Products,

        [string]$OutputPath,

        [switch]$Force
    )

    if (-not $script:ProjectRoot) {
        throw "Project root not set. Call Initialize-WorklabContext first."
    }

    if (-not $OutputPath) {
        $OutputPath = Join-Path $script:ProjectRoot "terraform" "labs" $LabName
    }

    # Check for existing lab
    if ((Test-Path $OutputPath) -and -not $Force) {
        throw "Lab directory already exists: $OutputPath. Use -Force to overwrite."
    }

    Write-Host "Creating lab: $LabName" -ForegroundColor Cyan

    # Step 1: Generate lab-config.yml
    $configPath = New-LabConfig `
        -LabName $LabName `
        -VlanId $VlanId `
        -IpCidr $IpCidr `
        -Domain $Domain `
        -Products $Products `
        -OutputPath $OutputPath

    if (-not $configPath) { return }

    # Step 2: Generate Terraform files
    $tfFiles = New-LabTerraform -LabName $LabName -LabConfigPath $configPath

    # Summary
    Write-Host ""
    Write-Host "Lab $LabName created in $OutputPath" -ForegroundColor Green
    Write-Host "  Config:    lab-config.yml (edit before deploying)" -ForegroundColor DarkGray
    Write-Host "  Terraform: $($tfFiles.Count) files generated" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor DarkGray
    Write-Host "  1. Review/edit lab-config.yml if needed" -ForegroundColor DarkGray
    Write-Host "  2. Run: New-LabTerraform -LabName $LabName  (to regenerate after edits)" -ForegroundColor DarkGray
    Write-Host "  3. Deploy with Spinup.ps1" -ForegroundColor DarkGray
}
