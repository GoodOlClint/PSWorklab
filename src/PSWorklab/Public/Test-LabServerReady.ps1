function Test-LabServerReady {
    <#
    .SYNOPSIS
        Checks whether all prerequisites for lab server operation are in place.
    .DESCRIPTION
        Validates that required tools, modules, vault configuration, and worklab
        config are present. Returns $true if everything is ready, $false with
        diagnostic messages if any checks fail.

        Run this after Initialize-LabServer or to diagnose issues.
    .EXAMPLE
        if (-not (Test-LabServerReady)) { Write-Host "Run Initialize-LabServer first." }
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $allPassed = $true

    # PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "FAIL: PowerShell 7.0+ required (current: $($PSVersionTable.PSVersion))" -ForegroundColor Red
        $allPassed = $false
    }
    else {
        Write-Host "  OK: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    }

    # Required modules
    foreach ($mod in @('Microsoft.PowerShell.SecretManagement', 'powershell-yaml', 'PSHcl')) {
        if (Get-Module -ListAvailable -Name $mod) {
            Write-Host "  OK: Module $mod" -ForegroundColor DarkGray
        }
        else {
            Write-Host "FAIL: Module $mod not installed. Install-Module $mod -Scope CurrentUser" -ForegroundColor Red
            $allPassed = $false
        }
    }

    # External tools
    foreach ($tool in @('packer', 'terraform')) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            $version = & $tool version 2>&1 | Select-Object -First 1
            Write-Host "  OK: $tool ($version)" -ForegroundColor DarkGray
        }
        else {
            Write-Host "FAIL: $tool not found on PATH" -ForegroundColor Red
            $allPassed = $false
        }
    }

    # Vault
    $defaultVault = Get-SecretVault -ErrorAction SilentlyContinue | Where-Object { $_.IsDefault } | Select-Object -First 1
    if ($defaultVault) {
        Write-Host "  OK: Default vault '$($defaultVault.Name)'" -ForegroundColor DarkGray
    }
    else {
        Write-Host "FAIL: No default SecretManagement vault registered" -ForegroundColor Red
        Write-Host "      Register-SecretVault -Name 'MyVault' -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault" -ForegroundColor Yellow
        $allPassed = $false
    }

    # Project root and config
    if ($script:ProjectRoot -and (Test-Path (Join-Path $script:ProjectRoot "worklab-config.yml"))) {
        $config = Get-WorklabConfig
        $hypervisor = Get-ConfigValue $config 'hypervisor'
        if ($hypervisor) {
            Write-Host "  OK: worklab-config.yml (hypervisor: $hypervisor)" -ForegroundColor DarkGray
        }
        else {
            Write-Host "FAIL: worklab-config.yml missing 'hypervisor' setting" -ForegroundColor Red
            $allPassed = $false
        }
    }
    else {
        Write-Host "FAIL: Project root not set or worklab-config.yml not found" -ForegroundColor Red
        Write-Host "      Call Initialize-WorklabContext -ProjectRoot <path> first" -ForegroundColor Yellow
        $allPassed = $false
    }

    # API token in vault
    if ($script:VaultName) {
        $tokenInfo = Get-SecretInfo -Vault $script:VaultName -Name $script:ProxmoxTokenSecretName -ErrorAction SilentlyContinue
        if ($tokenInfo) {
            Write-Host "  OK: Proxmox API token in vault" -ForegroundColor DarkGray
        }
        else {
            Write-Host "WARN: No Proxmox API token in vault. Run Initialize-ProxmoxToken." -ForegroundColor Yellow
        }
    }

    # Template registry
    $regPath = if ($script:ProjectRoot) { Join-Path $script:ProjectRoot "build-info" "worklab-templates.yml" } else { $null }
    if ($regPath -and (Test-Path $regPath)) {
        $reg = Get-Content $regPath -Raw | ConvertFrom-Yaml
        $count = if ($reg -and $reg.Contains('templates')) { $reg.templates.Count } else { 0 }
        if ($count -gt 0) {
            Write-Host "  OK: Template registry ($count template(s))" -ForegroundColor DarkGray
        }
        else {
            Write-Host "WARN: Template registry is empty. Build templates with Packer first." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "WARN: No template registry found. Build templates with Packer first." -ForegroundColor Yellow
    }

    if ($allPassed) {
        Write-Host ""
        Write-Host "Lab server is ready." -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "Some prerequisites are missing. Address the FAIL items above." -ForegroundColor Red
    }

    return $allPassed
}
