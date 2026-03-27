# Load private (module-scoped) state first
foreach ($file in (Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# Load public functions
foreach ($file in (Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)) {
    . $file.FullName
}
