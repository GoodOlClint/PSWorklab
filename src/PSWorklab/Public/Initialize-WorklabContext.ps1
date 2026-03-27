function Initialize-WorklabContext {
    <#
    .SYNOPSIS
        Sets the project root for this session. Call once at the top of each script.
    .DESCRIPTION
        All config/secret functions use the project root to locate worklab-config.yml
        and other project files. This replaces the old $script:ProjectRoot pattern.
    .EXAMPLE
        Initialize-WorklabContext -ProjectRoot (Split-Path $PSScriptRoot)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$ProjectRoot
    )

    $script:ProjectRoot = $ProjectRoot
}
