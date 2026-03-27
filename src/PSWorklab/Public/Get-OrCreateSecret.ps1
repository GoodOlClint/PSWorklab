function Get-OrCreateSecret {
    <#
    .SYNOPSIS
        Retrieves a secret from the vault, creating it if it doesn't exist.
    .DESCRIPTION
        Idempotent: returns the existing value if present, generates and
        stores a new password if missing (or if -Force is specified).
    .PARAMETER Path
        The vault secret name (e.g., worklab/template/server-2025/admin_password).
    .PARAMETER Length
        Password length for newly generated secrets. Defaults to 24.
    .PARAMETER Force
        Regenerate the secret even if it already exists.
    .EXAMPLE
        $password = Get-OrCreateSecret -Path 'worklab/template/server-2025/admin_password'
    .EXAMPLE
        $password = Get-OrCreateSecret -Path 'worklab/lab/lab-03/admin_password' -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateRange(12, 128)]
        [int]$Length = 24,

        [switch]$Force
    )

    if (-not $Force) {
        $existing = Get-SecretInfo -Vault $script:VaultName -Name $Path -ErrorAction SilentlyContinue
        if ($existing) {
            $value = Get-Secret -Vault $script:VaultName -Name $Path -AsPlainText -ErrorAction Stop
            Write-Host "  Retrieved secret: $Path" -ForegroundColor DarkGray
            return $value
        }
    }

    if ($PSCmdlet.ShouldProcess("Secret '$Path' in vault '$($script:VaultName)'", "Generate and store new secret")) {
        $password = New-ComplexPassword -Length $Length
        Set-Secret -Vault $script:VaultName -Name $Path -Secret $password -ErrorAction Stop
        Write-Host "  Generated secret: $Path" -ForegroundColor DarkGray
        return $password
    }
}
