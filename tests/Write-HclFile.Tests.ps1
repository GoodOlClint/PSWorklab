BeforeAll {
    # Write-HclFile depends on Import-PSHcl and PSHcl cmdlets
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Import-PSHcl.ps1')
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Write-HclFile.ps1')
}

# -Skip must evaluate at discovery time (before BeforeAll), so check inline
Describe 'Write-HclFile' -Skip:(-not (Get-Module -ListAvailable PSHcl)) {
    BeforeEach {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "write-hcl-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    }

    It 'Writes a valid HCL file' {
        $hcl = @'
variable "api_token" {
  type      = string
  sensitive = true
}
'@
        Write-HclFile -Hcl $hcl -Path $tempDir -FileName 'variables.tf'
        $outFile = Join-Path $tempDir 'variables.tf'
        Test-Path $outFile | Should -BeTrue
        $content = Get-Content $outFile -Raw
        $content | Should -Match 'variable\s+"api_token"'
    }

    It 'Throws on invalid HCL' {
        $badHcl = @'
variable "broken {
  type = string
'@
        { Write-HclFile -Hcl $badHcl -Path $tempDir -FileName 'bad.tf' } | Should -Throw '*syntax error*'
    }

    It 'Does not write with -WhatIf' {
        $hcl = @'
variable "test" {
  type = string
}
'@
        Write-HclFile -Hcl $hcl -Path $tempDir -FileName 'test.tf' -WhatIf
        Test-Path (Join-Path $tempDir 'test.tf') | Should -BeFalse
    }
}

Describe 'Write-HclFile (PSHcl not available)' -Skip:([bool](Get-Module -ListAvailable PSHcl)) {
    It 'Would skip -- PSHcl module is not installed' {
        Set-ItResult -Skipped -Because 'PSHcl module is not installed'
    }
}
