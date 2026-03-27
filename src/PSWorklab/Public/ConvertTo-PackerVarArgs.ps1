function ConvertTo-PackerVarArgs {
    <#
    .SYNOPSIS
        Converts a hashtable of key-value pairs into a Packer/Terraform -var argument array.
    .DESCRIPTION
        Takes a hashtable and produces an array of alternating '-var' and 'key=value'
        strings suitable for splatting to packer or terraform commands. Null or empty
        values are skipped.

        Optionally prepends a subcommand (e.g., 'build', 'plan') and appends
        -var-file paths and trailing arguments (e.g., the build file path).
    .PARAMETER Variables
        Hashtable of variable names and values.
    .PARAMETER Subcommand
        Optional subcommand to prepend (e.g., 'build', 'plan', 'apply').
    .PARAMETER VarFiles
        Optional array of -var-file paths to include.
    .PARAMETER TrailingArgs
        Optional arguments to append after all -var/-var-file entries (e.g., the
        build file path or '.' for the current directory).
    .EXAMPLE
        $vars = @{
            proxmox_api_url  = $config.proxmox.api_url
            proxmox_node     = $config.proxmox.node
            vm_id            = 9001
        }
        $args = ConvertTo-PackerVarArgs -Variables $vars -Subcommand build -TrailingArgs $BuildFile
        & packer @args
    .EXAMPLE
        $args = ConvertTo-PackerVarArgs -Variables $vars -VarFiles @($secretVarFile) -TrailingArgs '.'
        & packer @args
    .OUTPUTS
        System.String[] -- argument array suitable for splatting.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Variables,

        [string]$Subcommand,

        [string[]]$VarFiles,

        [string[]]$TrailingArgs
    )

    $args = [System.Collections.Generic.List[string]]::new()

    if ($Subcommand) {
        $args.Add($Subcommand)
    }

    foreach ($varFile in $VarFiles) {
        if ($varFile) {
            $args.Add("-var-file=$varFile")
        }
    }

    foreach ($key in ($Variables.Keys | Sort-Object)) {
        $value = $Variables[$key]
        if ($null -ne $value -and "$value" -ne '') {
            $args.Add("-var")
            $args.Add("$key=$value")
        }
    }

    foreach ($arg in $TrailingArgs) {
        if ($arg) {
            $args.Add($arg)
        }
    }

    return [string[]]$args
}
