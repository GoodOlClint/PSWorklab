function Resolve-TemplateVmId {
    <#
    .SYNOPSIS
        Resolves a template name to its VM ID from the template registry.
    .DESCRIPTION
        Looks up a template by friendly name (e.g., 'server-2025') in the registry
        and returns the VM ID for the specified hypervisor. Supports both the nested
        format (templates.name.hypervisor.vm_id) and the legacy flat format
        (templates.name.vm_id).

        Can also perform a reverse lookup: given a numeric VM ID, returns the
        friendly template name.
    .PARAMETER TemplateName
        The template name or numeric VM ID to resolve.
    .PARAMETER Hypervisor
        The hypervisor to look up. Defaults to the value from worklab-config.yml.
    .PARAMETER Registry
        A pre-loaded registry hashtable. If not provided, loads from the default path.
    .PARAMETER RegistryPath
        Override path to the registry file.
    .EXAMPLE
        Resolve-TemplateVmId -TemplateName server-2025
        # Returns: @{ VmId = 9001; Name = 'server-2025' }
    .EXAMPLE
        Resolve-TemplateVmId -TemplateName 9001
        # Reverse lookup returns: @{ VmId = 9001; Name = 'server-2025' }
    .OUTPUTS
        PSCustomObject with VmId (int) and Name (string) properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [string]$TemplateName,

        [string]$Hypervisor,

        [hashtable]$Registry,

        [string]$RegistryPath
    )

    if (-not $Registry) {
        $Registry = Get-TemplateRegistry -RegistryPath $RegistryPath
    }

    if (-not $Hypervisor) {
        $config = Get-WorklabConfig
        $Hypervisor = Get-ConfigValue $config 'hypervisor' 'proxmox'
    }

    # Numeric VM ID -- reverse lookup
    if ($TemplateName -match '^\d+$') {
        foreach ($key in $Registry.templates.Keys) {
            $tplEntry = $Registry.templates[$key]
            $tplVmId = $null
            if ($tplEntry.Contains($Hypervisor) -and $tplEntry[$Hypervisor] -is [hashtable]) {
                $tplVmId = $tplEntry[$Hypervisor].vm_id
            }
            elseif ($tplEntry.Contains('vm_id')) {
                $tplVmId = $tplEntry.vm_id
            }
            if ([string]$tplVmId -eq $TemplateName) {
                return [PSCustomObject]@{
                    VmId = [int]$TemplateName
                    Name = $key
                }
            }
        }
        # No match found -- return with null name
        return [PSCustomObject]@{
            VmId = [int]$TemplateName
            Name = $null
        }
    }

    # Friendly name lookup
    if (-not $Registry.templates.Contains($TemplateName)) {
        $available = $Registry.templates.Keys -join ', '
        throw "Template '$TemplateName' not found in registry. Available: $available"
    }

    $entry = $Registry.templates[$TemplateName]

    # Nested format: templates.name.hypervisor.vm_id
    if ($entry.Contains($Hypervisor) -and $entry[$Hypervisor] -is [hashtable]) {
        return [PSCustomObject]@{
            VmId = [int]$entry[$Hypervisor].vm_id
            Name = $TemplateName
        }
    }

    # Flat format: templates.name.vm_id
    if ($entry.Contains('vm_id')) {
        return [PSCustomObject]@{
            VmId = [int]$entry.vm_id
            Name = $TemplateName
        }
    }

    throw "Template '$TemplateName' has no entry for hypervisor '$Hypervisor' and no flat vm_id."
}
