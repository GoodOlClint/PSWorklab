function Set-WorklabConfigValue {
    <#
    .SYNOPSIS
        Updates a single YAML key in worklab-config.yml, preserving comments and key order.
    .DESCRIPTION
        Scans the file line by line for the section header, then replaces the target key's
        value. Only supports simple scalar values that are direct children of a top-level
        section (e.g., proxmox.api_token_id, pfsense.api_url).

        Does NOT support nested sub-sections, multi-line values, or flow sequences.
    .EXAMPLE
        Set-WorklabConfigValue -Section proxmox -Key api_token_id -Value 'root@pam!worklab'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Section,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Value,

        [string]$ConfigPath
    )

    if (-not $ConfigPath) {
        if (-not $script:ProjectRoot) {
            throw "Project root not set. Call Initialize-WorklabContext first."
        }
        $ConfigPath = Join-Path $script:ProjectRoot "worklab-config.yml"
    }

    $lines = Get-Content $ConfigPath
    $inSection = $false
    $found = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Top-level section header (no leading whitespace)
        if ($line -match '^(\S.*):\s*$' -or $line -match '^(\S.*):\s+\S') {
            $inSection = ($line -match "^${Section}:")
        }

        # Direct child key (exactly 2-space indent)
        if ($inSection -and $line -match "^  ${Key}:\s") {
            # Preserve inline YAML comments (space + # signals a comment; bare # in values is not a comment)
            if ($line -match '^(  ' + [regex]::Escape($Key) + ':\s*)\S.*?(\s+#.*)$') {
                $lines[$i] = "  ${Key}: ${Value}$($Matches[2])"
            }
            else {
                $lines[$i] = "  ${Key}: ${Value}"
            }
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Warning "Could not find ${Section}.${Key} in $ConfigPath -- update manually."
        return
    }

    if ($PSCmdlet.ShouldProcess("${Section}.${Key} in $ConfigPath", "Update config value to '$Value'")) {
        Set-Content -Path $ConfigPath -Value $lines -Encoding UTF8
        Write-Host "  Updated ${Section}.${Key} in $ConfigPath" -ForegroundColor DarkGray
    }
}
