function Set-TrackedEnvVar {
    <#
    .SYNOPSIS
        Sets a process environment variable and records its name for later cleanup.
    .DESCRIPTION
        Used by Import-LabSecret to track which env vars were set so that
        Remove-LabSecret can clean up exactly what was loaded.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($PSCmdlet.ShouldProcess("env:$Name", "Set environment variable")) {
        [System.Environment]::SetEnvironmentVariable($Name, $Value, "Process")
        if ($Name -notin $script:LoadedEnvVars) {
            $script:LoadedEnvVars.Add($Name)
        }
    }
}
