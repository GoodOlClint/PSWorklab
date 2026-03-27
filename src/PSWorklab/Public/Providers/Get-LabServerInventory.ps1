function Get-LabServerInventory {
    <#
    .SYNOPSIS
        Discovers the hypervisor host topology and returns available resources.
    .DESCRIPTION
        Queries the connected hypervisor to discover nodes, storage pools,
        network bridges, existing VMs, available ISOs, and SDN zones. This
        information is used by Initialize-LabServer to auto-populate
        worklab-config.yml.

        Currently supports Proxmox only. Requires an active connection
        (via Connect-WorklabProxmox or Initialize-ProxmoxToken).
    .PARAMETER UpdateConfig
        Write discovered values back to worklab-config.yml. Prompts for
        confirmation before each update.
    .EXAMPLE
        $inventory = Get-LabServerInventory
        $inventory.Nodes
        $inventory.StoragePools
    .EXAMPLE
        Get-LabServerInventory -UpdateConfig
    .OUTPUTS
        PSCustomObject with Nodes, StoragePools, Bridges, ExistingVMs, IsoFiles, SdnZones.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [switch]$UpdateConfig
    )

    Import-PSProxmoxVE

    $config = Get-WorklabConfig
    $hypervisor = Get-ConfigValue $config 'hypervisor' 'proxmox'

    if ($hypervisor -ne 'proxmox') {
        throw "Get-LabServerInventory currently only supports Proxmox. Hypervisor is set to '$hypervisor'."
    }

    Write-Host "Discovering Proxmox host topology..." -ForegroundColor Cyan

    # Nodes
    $nodes = @(Get-PveNode | ForEach-Object {
        [PSCustomObject]@{
            Name   = $_.Node
            Status = $_.Status
            Cpu    = $_.MaxCpu
            Memory = [math]::Round($_.MaxMem / 1GB, 1)
        }
    })
    Write-Host "  Nodes: $($nodes.Count) ($($nodes.Name -join ', '))" -ForegroundColor DarkGray

    # Storage pools (filter for VM disk-capable types)
    $storagePools = @(Get-PveStorage | Where-Object {
        $_.Content -match 'images|rootdir'
    } | ForEach-Object {
        [PSCustomObject]@{
            Name       = $_.Storage
            Type       = $_.Type
            Content    = $_.Content
            TotalGB    = if ($_.Total) { [math]::Round($_.Total / 1GB, 1) } else { $null }
            AvailGB    = if ($_.Avail) { [math]::Round($_.Avail / 1GB, 1) } else { $null }
        }
    })
    Write-Host "  Storage pools: $($storagePools.Count) ($($storagePools.Name -join ', '))" -ForegroundColor DarkGray

    # Network bridges
    $bridges = @(Get-PveNetwork -Node $nodes[0].Name -ErrorAction SilentlyContinue | Where-Object {
        $_.Type -eq 'bridge'
    } | ForEach-Object {
        [PSCustomObject]@{
            Name    = $_.Iface
            Address = $_.Address
            Cidr    = $_.Cidr
            Active  = $_.Active
        }
    })
    Write-Host "  Bridges: $($bridges.Count) ($($bridges.Name -join ', '))" -ForegroundColor DarkGray

    # Existing VMs
    $existingVMs = @(Get-PveVm -Node $nodes[0].Name -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            VmId   = $_.VmId
            Name   = $_.Name
            Status = $_.Status
        }
    })
    Write-Host "  Existing VMs: $($existingVMs.Count)" -ForegroundColor DarkGray

    # ISO files (check storage pools that support iso content)
    $isoStorages = @(Get-PveStorage | Where-Object { $_.Content -match 'iso' })
    $isoFiles = @()
    foreach ($store in $isoStorages) {
        $contents = @(Get-PveStorageContent -Node $nodes[0].Name -Storage $store.Storage -Content iso -ErrorAction SilentlyContinue)
        foreach ($iso in $contents) {
            $isoFiles += [PSCustomObject]@{
                Storage = $store.Storage
                VolId   = $iso.VolId
                Size    = if ($iso.Size) { [math]::Round($iso.Size / 1MB, 0) } else { $null }
            }
        }
    }
    Write-Host "  ISO files: $($isoFiles.Count)" -ForegroundColor DarkGray

    # SDN zones
    $sdnZones = @(Get-PveSdnZone -ErrorAction SilentlyContinue | ForEach-Object {
        [PSCustomObject]@{
            Zone = $_.Zone
            Type = $_.Type
        }
    })
    Write-Host "  SDN zones: $($sdnZones.Count) ($($sdnZones.Zone -join ', '))" -ForegroundColor DarkGray

    $inventory = [PSCustomObject]@{
        Nodes        = $nodes
        StoragePools = $storagePools
        Bridges      = $bridges
        ExistingVMs  = $existingVMs
        IsoFiles     = $isoFiles
        SdnZones     = $sdnZones
    }

    if ($UpdateConfig -and $nodes.Count -gt 0) {
        Write-Host ""
        Write-Host "Updating worklab-config.yml with discovered values..." -ForegroundColor Cyan

        # Node name (use first node)
        $currentNode = Get-ConfigValue $config 'proxmox.node'
        if (-not $currentNode -or $currentNode -ne $nodes[0].Name) {
            Set-WorklabConfigValue -Section proxmox -Key node -Value $nodes[0].Name
        }

        # Storage pool (use first VM-capable pool if not already set)
        $currentStorage = Get-ConfigValue $config 'proxmox.storage_pool'
        if (-not $currentStorage -and $storagePools.Count -gt 0) {
            Set-WorklabConfigValue -Section proxmox -Key storage_pool -Value $storagePools[0].Name
        }

        # Lab bridge (suggest vmbr1 or second bridge if available)
        $currentBridge = Get-ConfigValue $config 'proxmox.lab_bridge'
        if (-not $currentBridge -and $bridges.Count -gt 1) {
            $labBridge = $bridges | Where-Object { $_.Name -ne 'vmbr0' } | Select-Object -First 1
            if ($labBridge) {
                Set-WorklabConfigValue -Section proxmox -Key lab_bridge -Value $labBridge.Name
            }
        }
    }

    return $inventory
}
