function Remove-SecretVarFile {
    <#
    .SYNOPSIS
        Securely removes a secret var file created by New-SecretVarFile.
    .DESCRIPTION
        Overwrites the file contents before deletion to reduce the window where
        secrets are recoverable from disk. Safe to call if the file does not exist.
    .PARAMETER Path
        Path to the secret var file to remove.
    .EXAMPLE
        Remove-SecretVarFile -Path $varFile
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return }

    if ($PSCmdlet.ShouldProcess($Path, "Remove secret var file")) {
        # Overwrite with zeros before deleting
        $length = (Get-Item $Path).Length
        if ($length -gt 0) {
            $zeros = [byte[]]::new([Math]::Min($length, 4096))
            [System.IO.File]::WriteAllBytes($Path, $zeros)
        }
        Remove-Item -Path $Path -Force
        Write-Host "  Removed secret var file: $Path" -ForegroundColor DarkGray
    }
}
