function Register-Template {
    <#
    .SYNOPSIS
        Adds or updates a template entry in the template registry after a successful build.
    .DESCRIPTION
        Reads the registry (or creates it if missing), upserts the template entry under
        the hypervisor key, maintains backward-compatible flat fields, and writes the
        file back with a header comment.
    .PARAMETER TemplateName
        The friendly template name (e.g., 'server-2025', 'server-2025-sql2022').
    .PARAMETER VmId
        The VM ID assigned to the template.
    .PARAMETER Hypervisor
        The hypervisor the template was built for. Defaults to the value from config.
    .PARAMETER SqlVersion
        Optional SQL Server version string (e.g., '2022') if the template includes SQL.
    .PARAMETER RegistryPath
        Override path to the registry file. Defaults to build-info/worklab-templates.yml.
    .EXAMPLE
        Register-Template -TemplateName server-2025 -VmId 9001
    .EXAMPLE
        Register-Template -TemplateName server-2025-sql2022 -VmId 9002 -SqlVersion 2022
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$TemplateName,

        [Parameter(Mandatory)]
        [int]$VmId,

        [string]$Hypervisor,

        [string]$SqlVersion,

        [string]$RegistryPath
    )

    if (-not $RegistryPath) {
        if (-not $script:ProjectRoot) {
            throw "Project root not set. Call Initialize-WorklabContext first."
        }
        $RegistryPath = Join-Path $script:ProjectRoot "build-info" "worklab-templates.yml"
    }

    if (-not $Hypervisor) {
        $config = Get-WorklabConfig
        $Hypervisor = Get-ConfigValue $config 'hypervisor' 'proxmox'
    }

    # Build the hypervisor-specific entry
    $hypervisorEntry = [ordered]@{
        vm_id = $VmId
        built = (Get-Date -Format "o")
    }
    if ($SqlVersion) {
        $hypervisorEntry.sql_version = $SqlVersion
    }

    # Read existing registry or create empty one
    $registry = $null
    if (Test-Path $RegistryPath) {
        $registry = Get-Content $RegistryPath -Raw | ConvertFrom-Yaml
    }
    if (-not $registry -or -not $registry.Contains('templates')) {
        $registry = @{ templates = [ordered]@{} }
    }

    if ($PSCmdlet.ShouldProcess("$TemplateName (VM ID $VmId) in $RegistryPath", "Register template")) {
        # Upsert the template entry under the hypervisor key
        if (-not $registry.templates[$TemplateName]) {
            $registry.templates[$TemplateName] = @{}
        }
        $registry.templates[$TemplateName][$Hypervisor] = $hypervisorEntry

        # Backward-compatible flat fields
        $registry.templates[$TemplateName].vm_id = $VmId
        $registry.templates[$TemplateName].built = $hypervisorEntry.built
        if ($SqlVersion) {
            $registry.templates[$TemplateName].sql_version = $SqlVersion
        }

        # Write back with header comment
        $yamlContent = "# build-info/worklab-templates.yml -- auto-maintained by Register-Template`n"
        $yamlContent += "# Do not edit manually. Entries are updated after each successful Packer build.`n"
        $yamlContent += ($registry | ConvertTo-Yaml)

        $parentDir = Split-Path $RegistryPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        Set-Content -Path $RegistryPath -Value $yamlContent -Encoding UTF8 -NoNewline

        Write-Host "  Registry: $RegistryPath" -ForegroundColor DarkGray
        Write-Host "  Entry:    $TemplateName -> VM ID $VmId ($Hypervisor)" -ForegroundColor Green
    }
}
