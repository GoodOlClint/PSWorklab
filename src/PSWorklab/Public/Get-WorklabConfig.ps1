function Get-WorklabConfig {
    <#
    .SYNOPSIS
        Loads worklab-config.yml and returns it as a hashtable.
    .DESCRIPTION
        Reads the YAML config file from the project root (or a custom path) and
        optionally validates that required fields are present and non-empty.
    .PARAMETER RequiredFields
        Dot-separated field paths (e.g., 'proxmox.api_url') that must be non-empty.
    .PARAMETER ConfigPath
        Override path to the config file. Defaults to worklab-config.yml in the project root.
    .EXAMPLE
        $config = Get-WorklabConfig
    .EXAMPLE
        $config = Get-WorklabConfig -RequiredFields @('hypervisor', 'proxmox.api_url')
    #>
    [CmdletBinding()]
    param (
        [string[]]$RequiredFields,
        [string]$ConfigPath
    )

    if (-not $ConfigPath) {
        if (-not $script:ProjectRoot) {
            throw "Project root not set. Call Initialize-WorklabContext first."
        }
        $ConfigPath = Join-Path $script:ProjectRoot "worklab-config.yml"
    }

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath`nRun initial setup -- see README.md."
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Yaml

    foreach ($field in $RequiredFields) {
        $value = $config
        foreach ($part in ($field -split '\.')) {
            if ($value -is [hashtable] -and $value.Contains($part)) {
                $value = $value[$part]
            }
            else {
                $value = $null
                break
            }
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Required config field '$field' is empty in $ConfigPath"
        }
    }

    return $config
}
