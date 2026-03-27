function Remove-ScopedSecret {
    <#
    .SYNOPSIS
        Removes all vault secrets matching a scope/name prefix.
    .DESCRIPTION
        Finds all secrets under the worklab/<scope>/<name>/ prefix and removes them.
        Returns the count of secrets that matched (regardless of ShouldProcess).
    .PARAMETER Scope
        The worklab scope: template, foundation, or lab.
    .PARAMETER Name
        The resource name whose secrets should be removed.
    .EXAMPLE
        Remove-ScopedSecret -Scope lab -Name lab-03
        # Removes all secrets matching worklab/lab/lab-03/*
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('template', 'foundation', 'lab')]
        [string]$Scope,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $prefix = "worklab/$Scope/$Name/"
    $secrets = @(Get-SecretInfo -Vault $script:VaultName -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$prefix*" })

    foreach ($s in $secrets) {
        if ($PSCmdlet.ShouldProcess($s.Name, "Remove secret from $($script:VaultName)")) {
            Remove-Secret -Vault $script:VaultName -Name $s.Name -ErrorAction SilentlyContinue
            Write-Host "  Removed secret: $($s.Name)" -ForegroundColor DarkGray
        }
    }

    return $secrets.Count
}
