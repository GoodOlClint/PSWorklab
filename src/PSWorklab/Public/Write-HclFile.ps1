function Write-HclFile {
    <#
    .SYNOPSIS
        Validates an HCL string and writes it to disk with consistent formatting.
    .DESCRIPTION
        Uses PSHcl (a required module) to validate HCL syntax and round-trip format
        the content before writing. If validation fails, displays detailed error
        diagnostics with line numbers and throws.
    .PARAMETER Hcl
        The HCL content string to validate and write.
    .PARAMETER Path
        The directory to write the file into.
    .PARAMETER FileName
        The name of the file to create (e.g., main.tf, variables.tf).
    .EXAMPLE
        $hcl = @'
        variable "proxmox_api_token" {
          type      = string
          sensitive = true
        }
        '@
        Write-HclFile -Hcl $hcl -Path ./terraform/lab-03 -FileName variables.tf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Hcl,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FileName
    )

    $diags = Test-HclSyntax -InputObject $Hcl -Detailed
    $errors = @($diags | Where-Object { $_.Message -ne "OK" })
    if ($errors.Count -gt 0) {
        Write-Host "ERROR: Generated $FileName has HCL syntax errors:" -ForegroundColor Red
        foreach ($d in $errors) {
            Write-Host "  Line $($d.Line), Col $($d.Column): $($d.Message)" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "Generated HCL:" -ForegroundColor Yellow
        $lineNum = 1
        foreach ($line in ($Hcl -split "`n")) {
            Write-Host ("  {0,4}: {1}" -f $lineNum, $line)
            $lineNum++
        }
        throw "Generated $FileName has $($errors.Count) HCL syntax error(s)."
    }

    $filePath = Join-Path $Path $FileName
    if ($PSCmdlet.ShouldProcess($filePath, "Write formatted HCL file")) {
        # Round-trip through PSHcl for consistent formatting
        $formatted = ConvertFrom-Hcl -InputObject $Hcl | ConvertTo-Hcl
        Set-Content -Path $filePath -Value $formatted -Encoding UTF8
        Write-Host "  Wrote $FileName" -ForegroundColor DarkGray
    }
}
