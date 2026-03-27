BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'PSWorklab.psd1' | Resolve-Path
    $Manifest = Import-PowerShellDataFile $ModulePath
}

Describe 'Module manifest' {
    It 'Has a valid manifest' {
        $Manifest | Should -Not -BeNullOrEmpty
    }

    It 'Has a RootModule' {
        $Manifest.RootModule | Should -Be 'PSWorklab.psm1'
    }

    It 'Has a valid GUID' {
        { [guid]::Parse($Manifest.GUID) } | Should -Not -Throw
    }

    It 'Has a description' {
        $Manifest.Description | Should -Not -BeNullOrEmpty
    }

    It 'Has an author' {
        $Manifest.Author | Should -Not -BeNullOrEmpty
    }

    It 'Declares CompatiblePSEditions' {
        $Manifest.CompatiblePSEditions | Should -Contain 'Core'
    }

    It 'Requires PowerShell 7.0+' {
        [version]$Manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version]'7.0')
    }

    It 'Does not use wildcard exports' {
        $Manifest.FunctionsToExport | Should -Not -Contain '*'
        $Manifest.CmdletsToExport | Should -Not -Contain '*'
        $Manifest.AliasesToExport | Should -Not -Contain '*'
    }

    It 'Exports only approved verbs' {
        $approvedVerbs = (Get-Verb).Verb
        foreach ($fn in $Manifest.FunctionsToExport) {
            $verb = ($fn -split '-')[0]
            $verb | Should -BeIn $approvedVerbs -Because "$fn should use an approved verb"
        }
    }
}

Describe 'Module structure' {
    It 'Has a .ps1 file for each exported function' {
        $publicDir = Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' | Resolve-Path
        $files = Get-ChildItem -Path $publicDir -Filter '*.ps1' -Recurse |
            ForEach-Object { $_.BaseName }

        foreach ($fn in $Manifest.FunctionsToExport) {
            $fn | Should -BeIn $files -Because "exported function '$fn' should have a matching .ps1 file"
        }
    }

    It 'Has no orphan .ps1 files in Public that are not exported' {
        $publicDir = Join-Path $PSScriptRoot '..' 'src' 'PSWorklab' 'Public' | Resolve-Path
        $files = Get-ChildItem -Path $publicDir -Filter '*.ps1' -Recurse |
            ForEach-Object { $_.BaseName }

        foreach ($file in $files) {
            $file | Should -BeIn $Manifest.FunctionsToExport -Because "public file '$file.ps1' should be in FunctionsToExport"
        }
    }
}
