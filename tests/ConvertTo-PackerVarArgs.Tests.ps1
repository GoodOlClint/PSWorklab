BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'ConvertTo-PackerVarArgs.ps1')
}

Describe 'ConvertTo-PackerVarArgs' {
    It 'Produces alternating -var and key=value pairs' {
        $result = ConvertTo-PackerVarArgs -Variables @{ node = 'pve'; url = 'https://pve:8006' }
        $result | Should -Contain '-var'
        $result | Should -Contain 'node=pve'
        $result | Should -Contain 'url=https://pve:8006'
    }

    It 'Sorts keys alphabetically for deterministic output' {
        $result = ConvertTo-PackerVarArgs -Variables @{ zebra = '1'; alpha = '2' }
        # Find the positions of the key=value entries
        $alphaIdx = [array]::IndexOf($result, 'alpha=2')
        $zebraIdx = [array]::IndexOf($result, 'zebra=1')
        $alphaIdx | Should -BeLessThan $zebraIdx
    }

    It 'Prepends the subcommand' {
        $result = ConvertTo-PackerVarArgs -Variables @{ x = '1' } -Subcommand build
        $result[0] | Should -Be 'build'
    }

    It 'Includes -var-file entries before -var entries' {
        $result = ConvertTo-PackerVarArgs -Variables @{ x = '1' } -VarFiles @('secrets.json')
        $varFileIdx = [array]::IndexOf($result, '-var-file=secrets.json')
        $varIdx = [array]::IndexOf($result, '-var')
        $varFileIdx | Should -BeLessThan $varIdx
    }

    It 'Appends trailing args at the end' {
        $result = ConvertTo-PackerVarArgs -Variables @{ x = '1' } -TrailingArgs @('template.pkr.hcl')
        $result[-1] | Should -Be 'template.pkr.hcl'
    }

    It 'Skips null values' {
        $result = ConvertTo-PackerVarArgs -Variables @{ present = '1'; missing = $null }
        $result | Should -Contain 'present=1'
        ($result -match 'missing') | Should -HaveCount 0
    }

    It 'Skips empty string values' {
        $result = ConvertTo-PackerVarArgs -Variables @{ present = '1'; empty = '' }
        $result | Should -Contain 'present=1'
        ($result -match 'empty') | Should -HaveCount 0
    }

    It 'Handles all options together' {
        $result = ConvertTo-PackerVarArgs `
            -Variables @{ node = 'pve'; url = 'https://pve:8006' } `
            -Subcommand build `
            -VarFiles @('vars.json') `
            -TrailingArgs @('.')

        $result[0] | Should -Be 'build'
        $result[1] | Should -Be '-var-file=vars.json'
        $result[-1] | Should -Be '.'
        $result | Should -Contain 'node=pve'
    }

    It 'Returns an empty-ish array when no variables and no options' {
        $result = ConvertTo-PackerVarArgs -Variables @{}
        $result.Count | Should -Be 0
    }

    It 'Works with integer values' {
        $result = ConvertTo-PackerVarArgs -Variables @{ vm_id = 9001 }
        $result | Should -Contain 'vm_id=9001'
    }
}
