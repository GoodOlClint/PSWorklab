function Get-SqlIsoVersion {
    <#
    .SYNOPSIS
        Mounts a SQL Server ISO and returns the SQL version year.
    .DESCRIPTION
        Windows-only. Mounts the ISO, reads the ProductMajorPart from setup.exe,
        and maps it to a SQL Server release year.

        Throws if not running on Windows or if the ISO does not contain setup.exe.
    .PARAMETER Path
        Full path to the SQL Server ISO file.
    .EXAMPLE
        $year = Get-SqlIsoVersion -Path C:\ISOs\sql-server-2022.iso
        # Returns: '2022'
    .OUTPUTS
        System.String -- the SQL Server release year (e.g., '2016', '2019', '2022').
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    if (-not (Get-Command Mount-DiskImage -ErrorAction SilentlyContinue)) {
        throw "Mount-DiskImage not available. This requires Windows. Pass -SqlVersion explicitly to skip auto-detection."
    }

    $mount = Mount-DiskImage -ImagePath $Path -PassThru
    try {
        $drive = ($mount | Get-Volume).DriveLetter
        $setupExe = "${drive}:\setup.exe"
        if (-not (Test-Path $setupExe)) {
            throw "No setup.exe found in ISO -- is this a SQL Server ISO?"
        }

        $major = (Get-Item $setupExe).VersionInfo.ProductMajorPart
        $sqlYear = switch ($major) {
            13 { "2016" }
            14 { "2017" }
            15 { "2019" }
            16 { "2022" }
            17 { "2025" }
            default { throw "Unknown SQL Server major version: $major (setup.exe ProductMajorPart)" }
        }

        return $sqlYear
    }
    finally {
        Dismount-DiskImage -ImagePath $Path | Out-Null
    }
}
