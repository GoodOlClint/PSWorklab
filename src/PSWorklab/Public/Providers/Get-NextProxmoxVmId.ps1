function Get-NextProxmoxVmId {
    <#
    .SYNOPSIS
        Finds the next available VM ID at or above a minimum value on a Proxmox node.
    .DESCRIPTION
        Queries the Proxmox node for all existing VMs, then returns the lowest
        unused VM ID >= MinimumId. Used to allocate template VM IDs in the 9000+ range.

        Requires PSProxmoxVE (loaded via Import-PSProxmoxVE) and an active connection
        (via Connect-WorklabProxmox).
    .PARAMETER Node
        The Proxmox node name. Defaults to the value from worklab-config.yml.
    .PARAMETER MinimumId
        The minimum VM ID to consider. Defaults to 9000 (template range).
    .EXAMPLE
        $vmId = Get-NextProxmoxVmId
    .EXAMPLE
        $vmId = Get-NextProxmoxVmId -Node pve2 -MinimumId 1000
    .OUTPUTS
        System.Int32
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [string]$Node,

        [int]$MinimumId = 9000
    )

    Import-PSProxmoxVE

    if (-not $Node) {
        $config = Get-WorklabConfig
        $Node = Get-ConfigValue $config 'proxmox.node' 'pve'
    }

    $allVms = @(Get-PveVm -Node $Node)
    $usedIds = @($allVms | Where-Object { $_.VmId -ge $MinimumId } | ForEach-Object { $_.VmId })

    $nextId = $MinimumId
    while ($usedIds -contains $nextId) { $nextId++ }

    return $nextId
}
