function Remove-LabSecret {
    <#
    .SYNOPSIS
        Removes all secret environment variables set by Import-LabSecret.
    .DESCRIPTION
        Clears every process environment variable that was tracked by Import-LabSecret
        and resets the tracking list. Safe to call multiple times.
    .EXAMPLE
        try { Import-LabSecret; packer build ... }
        finally { Remove-LabSecret }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    if ($PSCmdlet.ShouldProcess("$($script:LoadedEnvVars.Count) env vars", "Clear secret environment variables")) {
        foreach ($name in $script:LoadedEnvVars) {
            [System.Environment]::SetEnvironmentVariable($name, $null, "Process")
        }
        $script:LoadedEnvVars.Clear()
    }
}
