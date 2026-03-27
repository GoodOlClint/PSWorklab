@{
    # This module targets PowerShell 7+ where Write-Host writes to the Information
    # stream (same as Write-Information) and is fully capturable via 6>. The
    # PSAvoidUsingWriteHost rule is a legacy concern from PS 2-4. Using Write-Host
    # gives colored console output without requiring ANSI escape sequences.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}
