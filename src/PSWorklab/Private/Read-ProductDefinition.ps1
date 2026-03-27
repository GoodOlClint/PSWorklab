function Read-ProductDefinition {
    <#
    .SYNOPSIS
        Loads and validates a product definition YAML from the products directory.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    if (-not $script:ProjectRoot) {
        throw "Project root not set. Call Initialize-WorklabContext first."
    }

    $prodFile = Join-Path $script:ProjectRoot "products" "$Name.yml"
    if (-not (Test-Path $prodFile)) {
        throw "Product definition not found: $prodFile"
    }

    $prodDef = Get-Content $prodFile -Raw | ConvertFrom-Yaml
    if (-not $prodDef) {
        throw "Product file is empty or invalid YAML: $prodFile"
    }

    if (-not $prodDef.Contains('versions')) {
        throw "Product '$Name' has no 'versions' key in $prodFile"
    }

    if (-not $prodDef.versions.Contains($Version)) {
        $available = $prodDef.versions.Keys -join ', '
        throw "Product '$Name' version '$Version' not found. Available: $available"
    }

    $versionDef = $prodDef.versions[$Version]
    if (-not $versionDef.Contains('vms') -or $versionDef.vms.Count -eq 0) {
        throw "Product '$Name' version '$Version' has no VMs defined."
    }

    return @{
        Name      = $Name
        Version   = $Version
        ShortName = if ($prodDef.Contains('short_name')) { $prodDef.short_name } else { $Name }
        FullName  = if ($prodDef.Contains('name')) { $prodDef.name } else { $Name }
        VMs       = $versionDef.vms
    }
}
