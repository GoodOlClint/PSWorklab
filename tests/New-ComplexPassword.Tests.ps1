BeforeAll {
    # Dot-source the function directly to test without full module load
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'New-ComplexPassword.ps1')
}

Describe 'New-ComplexPassword' {
    It 'Returns a string of the default length (24)' {
        $password = New-ComplexPassword
        $password | Should -BeOfType [string]
        $password.Length | Should -Be 24
    }

    It 'Respects the -Length parameter' {
        $password = New-ComplexPassword -Length 32
        $password.Length | Should -Be 32
    }

    It 'Contains at least one uppercase letter' {
        $password = New-ComplexPassword
        $password | Should -MatchExactly '[A-Z]'
    }

    It 'Contains at least one lowercase letter' {
        $password = New-ComplexPassword
        $password | Should -MatchExactly '[a-z]'
    }

    It 'Contains at least one digit' {
        $password = New-ComplexPassword
        $password | Should -MatchExactly '[0-9]'
    }

    It 'Contains at least one symbol' {
        $password = New-ComplexPassword
        $password | Should -MatchExactly '[!@#%\^*()_=+\[\];:,.?~-]'
    }

    It 'Does not contain shell-hostile characters' {
        # Run multiple times to increase confidence
        foreach ($i in 1..10) {
            $password = New-ComplexPassword
            $password | Should -Not -Match '[`$"''<>&\\{}]'
        }
    }

    It 'Generates unique passwords' {
        $passwords = 1..5 | ForEach-Object { New-ComplexPassword }
        ($passwords | Select-Object -Unique).Count | Should -Be 5
    }

    It 'Rejects length below 12' {
        { New-ComplexPassword -Length 8 } | Should -Throw
    }

    It 'Rejects length above 128' {
        { New-ComplexPassword -Length 200 } | Should -Throw
    }
}
