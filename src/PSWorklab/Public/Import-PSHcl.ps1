function Import-PSHcl {
    <#
    .SYNOPSIS
        Imports the PSHcl module, installing from PSGallery if needed.
    .DESCRIPTION
        Checks if PSHcl is already loaded, then if it is available on the module
        path. Throws with install instructions if not found.
    .EXAMPLE
        Import-PSHcl
    #>
    [CmdletBinding()]
    param ()

    if (Get-Module PSHcl) { return }

    if (Get-Module -ListAvailable PSHcl) {
        Import-Module PSHcl -ErrorAction Stop
        return
    }

    throw @"
PSHcl module not found. Install it:
  Install-Module PSHcl -Scope CurrentUser
"@
}
