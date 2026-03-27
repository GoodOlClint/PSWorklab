BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' 'Get-SecretPath.ps1')
}

Describe 'Get-SecretPath' {
    It 'Constructs a template path with name' {
        Get-SecretPath -Scope template -Name server-2025 -Key admin_password |
            Should -Be 'worklab/template/server-2025/admin_password'
    }

    It 'Constructs a lab path with name' {
        Get-SecretPath -Scope lab -Name lab-03 -Key admin_password |
            Should -Be 'worklab/lab/lab-03/admin_password'
    }

    It 'Constructs a foundation path without name' {
        Get-SecretPath -Scope foundation -Key admin_password |
            Should -Be 'worklab/foundation/admin_password'
    }

    It 'Constructs a foundation path with optional name' {
        Get-SecretPath -Scope foundation -Name extra -Key admin_password |
            Should -Be 'worklab/foundation/extra/admin_password'
    }

    It 'Throws when Name is missing for template scope' {
        { Get-SecretPath -Scope template -Key admin_password } | Should -Throw '*-Name is required*'
    }

    It 'Throws when Name is missing for lab scope' {
        { Get-SecretPath -Scope lab -Key admin_password } | Should -Throw '*-Name is required*'
    }

    It 'Rejects invalid scope values' {
        { Get-SecretPath -Scope invalid -Key test } | Should -Throw
    }
}
