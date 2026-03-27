function Get-ConfigValue {
    <#
    .SYNOPSIS
        Reads a value from a config hashtable with a default fallback.
    .DESCRIPTION
        Navigates a dot-separated path through a nested hashtable and returns the
        value found, or the specified default if the path does not exist or is empty.
    .PARAMETER Config
        The hashtable returned by Get-WorklabConfig.
    .PARAMETER Path
        Dot-separated key path (e.g., 'proxmox.node').
    .PARAMETER Default
        Value to return if the path is not found or is empty.
    .EXAMPLE
        Get-ConfigValue $config 'hypervisor' 'proxmox'
    .EXAMPLE
        Get-ConfigValue $config 'proxmox.node' 'pve'
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [string]$Path,

        [object]$Default
    )

    $value = $Config
    foreach ($part in ($Path -split '\.')) {
        if ($value -is [hashtable] -and $value.Contains($part)) {
            $value = $value[$part]
        }
        else {
            return $Default
        }
    }

    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}
