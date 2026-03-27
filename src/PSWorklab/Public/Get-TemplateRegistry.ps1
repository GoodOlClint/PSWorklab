function Get-TemplateRegistry {
    <#
    .SYNOPSIS
        Loads the template registry (worklab-templates.yml) and returns it as a hashtable.
    .DESCRIPTION
        Reads the template registry from the build-info directory under the project root.
        The registry tracks which Packer templates have been built, their VM IDs, build
        dates, and optional metadata like SQL version.

        Returns the full registry hashtable. Use Resolve-TemplateVmId to look up
        individual templates.
    .PARAMETER RegistryPath
        Override path to the registry file. Defaults to build-info/worklab-templates.yml
        under the project root.
    .EXAMPLE
        $registry = Get-TemplateRegistry
        $registry.templates.Keys  # list all template names
    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    param (
        [string]$RegistryPath
    )

    if (-not $RegistryPath) {
        if (-not $script:ProjectRoot) {
            throw "Project root not set. Call Initialize-WorklabContext first."
        }
        $RegistryPath = Join-Path $script:ProjectRoot "build-info" "worklab-templates.yml"
    }

    if (-not (Test-Path $RegistryPath)) {
        throw "Template registry not found: $RegistryPath. Build a base template first."
    }

    $registry = Get-Content $RegistryPath -Raw | ConvertFrom-Yaml
    if (-not $registry -or -not $registry.Contains('templates')) {
        throw "Template registry at $RegistryPath is empty or missing 'templates' key."
    }

    return $registry
}
