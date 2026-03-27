function Import-PSProxmoxVE {
    <#
    .SYNOPSIS
        Imports the PSProxmoxVE module, searching known locations if needed.
    .DESCRIPTION
        Checks in order: already loaded, on PSModulePath, dev path at
        ~/Source/PSProxmoxVE. Throws with install instructions if not found.
    .EXAMPLE
        Import-PSProxmoxVE
    #>
    [CmdletBinding()]
    param ()

    if (Get-Module PSProxmoxVE) { return }

    if (Get-Module -ListAvailable PSProxmoxVE) {
        Import-Module PSProxmoxVE -ErrorAction Stop
        return
    }

    # Fallback: check known development path
    $devRoot = Join-Path -Path ([Environment]::GetFolderPath('UserProfile')) -ChildPath "Source" -AdditionalChildPath "PSProxmoxVE"
    $binDir = Join-Path -Path $devRoot -ChildPath "src" -AdditionalChildPath "PSProxmoxVE", "bin"
    $candidates = if (Test-Path $binDir) {
        @(Get-ChildItem -Path $binDir -Recurse -Filter "PSProxmoxVE.psd1" -ErrorAction SilentlyContinue)
    } else { @() }

    if ($candidates.Count -gt 0) {
        # Prefer Release build, then highest .NET version
        $manifest = $candidates |
            Sort-Object @(
                @{ Expression = { $_.FullName -match 'Release' }; Descending = $true }
                @{ Expression = { if ($_.FullName -match 'net(\d+)') { [int]$Matches[1] } else { 0 } }; Descending = $true }
            ) |
            Select-Object -First 1
        Import-Module $manifest.FullName -ErrorAction Stop
        Write-Host "  Loaded PSProxmoxVE from dev path: $($manifest.DirectoryName)" -ForegroundColor DarkGray
        return
    }

    throw @"
PSProxmoxVE module not found. Install it using one of:
  - PSGallery: Install-Module PSProxmoxVE -Scope CurrentUser
  - From source: cd ~/Source/PSProxmoxVE && dotnet build
"@
}
