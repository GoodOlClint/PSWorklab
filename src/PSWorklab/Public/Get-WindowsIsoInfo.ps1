function Get-WindowsIsoInfo {
    <#
    .SYNOPSIS
        Mounts a Windows Server ISO and returns the version year and WIM image name.
    .DESCRIPTION
        Windows-only. Uses Get-WindowsImage (DISM module) to inspect the install.wim
        inside the ISO. Prefers the Standard (Desktop Experience) edition.

        Throws if not running on Windows or if the ISO does not contain a recognized
        Windows Server image.
    .PARAMETER Path
        Full path to the Windows Server ISO file.
    .EXAMPLE
        $info = Get-WindowsIsoInfo -Path C:\ISOs\windows-server-2025.iso
        $info.ServerVersion  # '2025'
        $info.ImageName      # 'Windows Server 2025 SERVERSTANDARD'
    .OUTPUTS
        PSCustomObject with ServerVersion (string) and ImageName (string) properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    if (-not (Get-Command Get-WindowsImage -ErrorAction SilentlyContinue)) {
        throw "Get-WindowsImage not available. This requires Windows with the DISM module. Pass -ServerVersion explicitly to skip auto-detection."
    }

    $mount = Mount-DiskImage -ImagePath $Path -PassThru
    try {
        $drive = ($mount | Get-Volume).DriveLetter
        $wimPath = "${drive}:\sources\install.wim"
        if (-not (Test-Path $wimPath)) {
            throw "No install.wim found in ISO -- is this a Windows Server ISO?"
        }

        $images = @(Get-WindowsImage -ImagePath $wimPath)
        $target = @($images | Where-Object { $_.ImageName -match 'SERVERSTANDARD' }) | Select-Object -First 1
        if (-not $target) {
            throw "No SERVERSTANDARD image found in ISO. Available: $($images.ImageName -join ', ')"
        }

        if ($target.ImageName -match 'Windows Server (\d{4})') {
            $version = $Matches[1]
        }
        else {
            throw "Could not parse version from image name: $($target.ImageName)"
        }

        [PSCustomObject]@{
            ServerVersion = $version
            ImageName     = $target.ImageName
        }
    }
    finally {
        Dismount-DiskImage -ImagePath $Path | Out-Null
    }
}
