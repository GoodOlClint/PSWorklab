function Get-SecretPath {
    <#
    .SYNOPSIS
        Returns the vault secret name following the worklab naming convention.
    .DESCRIPTION
        Constructs a hierarchical secret path in the format worklab/<scope>/<name>/<key>.
        For the 'foundation' scope, the Name parameter is optional and the path format
        is worklab/foundation/<key>.
    .PARAMETER Scope
        The worklab scope: template, foundation, or lab.
    .PARAMETER Name
        The resource name (e.g., template or lab name). Required for template and lab scopes.
    .PARAMETER Key
        The secret key name (e.g., admin_password).
    .EXAMPLE
        Get-SecretPath -Scope template -Name server-2025 -Key admin_password
        # Returns: worklab/template/server-2025/admin_password
    .EXAMPLE
        Get-SecretPath -Scope foundation -Key pfsense_password
        # Returns: worklab/foundation/pfsense_password
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('template', 'foundation', 'lab')]
        [string]$Scope,

        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($Scope -ne 'foundation' -and -not $Name) {
        throw "Get-SecretPath: -Name is required for scope '$Scope'."
    }

    if ($Name) { return "worklab/$Scope/$Name/$Key" }
    return "worklab/$Scope/$Key"
}
