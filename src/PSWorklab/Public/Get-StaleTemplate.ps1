function Get-StaleTemplate {
    <#
    .SYNOPSIS
        Returns templates from the registry that are older than a specified threshold.
    .DESCRIPTION
        Reads the template registry and checks each template's build date against
        the MaxAgeDays threshold. Returns details for any template that needs rebuilding.

        Useful for maintenance workflows to identify templates that should be
        rebuilt with current OS patches.
    .PARAMETER MaxAgeDays
        Maximum age in days before a template is considered stale. Defaults to 30.
    .PARAMETER Hypervisor
        Only check templates for this hypervisor. Defaults to the value from config.
    .PARAMETER RegistryPath
        Override path to the template registry file.
    .EXAMPLE
        Get-StaleTemplate
        # Returns templates older than 30 days
    .EXAMPLE
        Get-StaleTemplate -MaxAgeDays 7
        # Returns templates older than 7 days
    .EXAMPLE
        Get-StaleTemplate -MaxAgeDays 0
        # Returns all templates (everything is stale at 0 days)
    .OUTPUTS
        PSCustomObject[] with Name, VmId, Built, AgeDays, Hypervisor properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [int]$MaxAgeDays = 30,

        [string]$Hypervisor,

        [string]$RegistryPath
    )

    $registry = Get-TemplateRegistry -RegistryPath $RegistryPath

    if (-not $Hypervisor) {
        $config = Get-WorklabConfig
        $Hypervisor = Get-ConfigValue $config 'hypervisor' 'proxmox'
    }

    $now = Get-Date
    $stale = @()

    foreach ($name in $registry.templates.Keys) {
        $entry = $registry.templates[$name]

        # Get build date and VM ID -- try hypervisor-specific first, then flat
        $built = $null
        $vmId = $null

        if ($entry.Contains($Hypervisor) -and $entry[$Hypervisor] -is [hashtable]) {
            $hvEntry = $entry[$Hypervisor]
            if ($hvEntry.Contains('built')) { $built = $hvEntry.built }
            if ($hvEntry.Contains('vm_id')) { $vmId = $hvEntry.vm_id }
        }

        # Fall back to flat format
        if (-not $built -and $entry.Contains('built')) { $built = $entry.built }
        if (-not $vmId -and $entry.Contains('vm_id')) { $vmId = $entry.vm_id }

        if (-not $built) {
            # No build date recorded -- treat as stale
            $stale += [PSCustomObject]@{
                Name       = $name
                VmId       = $vmId
                Built      = $null
                AgeDays    = [int]::MaxValue
                Hypervisor = $Hypervisor
            }
            continue
        }

        $builtDate = [datetime]::Parse($built)
        $ageDays = [int]($now - $builtDate).TotalDays

        if ($ageDays -ge $MaxAgeDays) {
            $stale += [PSCustomObject]@{
                Name       = $name
                VmId       = $vmId
                Built      = $builtDate
                AgeDays    = $ageDays
                Hypervisor = $Hypervisor
            }
        }
    }

    return $stale
}
