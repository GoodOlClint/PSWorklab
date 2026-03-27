function New-ComplexPassword {
    <#
    .SYNOPSIS
        Generates a cryptographically secure password meeting Windows/SQL complexity.
    .DESCRIPTION
        Uses System.Security.Cryptography.RandomNumberGenerator.
        Guarantees at least 1 uppercase, 1 lowercase, 1 digit, 1 symbol.
        Avoids shell-hostile characters: ` $ " ' < > & \ { }
    .PARAMETER Length
        Password length. Must be between 12 and 128. Defaults to 24.
    .EXAMPLE
        $password = New-ComplexPassword
    .EXAMPLE
        $password = New-ComplexPassword -Length 32
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param (
        [ValidateRange(12, 128)]
        [int]$Length = 24
    )

    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower   = 'abcdefghjkmnpqrstuvwxyz'
    $digits  = '23456789'
    $symbols = '!@#%^*()-_=+[];:,.?~'
    $all     = $upper + $lower + $digits + $symbols

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        # Unbiased random index: reject values that would cause modulo bias
        $pickRandom = {
            param ([string]$CharSet)
            $len = $CharSet.Length
            $limit = 256 - (256 % $len)
            do {
                $bytes = [byte[]]::new(1)
                $rng.GetBytes($bytes)
            } while ($bytes[0] -ge $limit)
            return $CharSet[$bytes[0] % $len]
        }

        # Guarantee one of each class
        $chars = [System.Collections.Generic.List[char]]::new()
        $chars.Add((&$pickRandom $upper))
        $chars.Add((&$pickRandom $lower))
        $chars.Add((&$pickRandom $digits))
        $chars.Add((&$pickRandom $symbols))

        for ($i = 4; $i -lt $Length; $i++) {
            $chars.Add((&$pickRandom $all))
        }

        # Fisher-Yates shuffle (4 bytes per index for negligible bias on small arrays)
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $buf = [byte[]]::new(4)
            $rng.GetBytes($buf)
            $j = [System.Math]::Abs([System.BitConverter]::ToInt32($buf, 0)) % ($i + 1)
            $temp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $temp
        }
    }
    finally {
        $rng.Dispose()
    }

    return -join $chars
}
