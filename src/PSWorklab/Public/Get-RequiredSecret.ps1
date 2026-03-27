function Get-RequiredSecret {
    <#
    .SYNOPSIS
        Retrieves a secret that must already exist in the vault. Throws if missing.
    .DESCRIPTION
        Use this for secrets that are provisioned by the user or a prior setup step
        and must be present before the current operation can proceed.
    .PARAMETER Path
        The vault secret name to retrieve.
    .EXAMPLE
        $password = Get-RequiredSecret -Path 'worklab/foundation/pfsense_password'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $existing = Get-SecretInfo -Vault $script:VaultName -Name $Path -ErrorAction SilentlyContinue
    if (-not $existing) {
        throw "Required secret '$Path' not found in vault '$($script:VaultName)'. Was the prerequisite step completed?"
    }

    return Get-Secret -Vault $script:VaultName -Name $Path -AsPlainText -ErrorAction Stop
}
