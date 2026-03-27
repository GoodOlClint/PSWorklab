function Wait-TcpReady {
    <#
    .SYNOPSIS
        Waits for a TCP port to become reachable, with timeout.
    .DESCRIPTION
        Polls a TCP port in a loop until it connects or the timeout elapses.
        Cross-platform -- uses TcpClient instead of Test-NetConnection.
    .PARAMETER IP
        The IP address or hostname to connect to.
    .PARAMETER Port
        The TCP port number.
    .PARAMETER Name
        A friendly name for log output. Defaults to "IP:Port".
    .PARAMETER TimeoutSeconds
        Maximum time to wait before throwing. Defaults to 300 (5 minutes).
    .PARAMETER PollIntervalSeconds
        Seconds between connection attempts. Defaults to 5.
    .EXAMPLE
        Wait-TcpReady -IP 10.101.0.10 -Port 5986 -Name "DC1 WinRM" -TimeoutSeconds 300
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$IP,

        [Parameter(Mandatory)]
        [int]$Port,

        [string]$Name = "${IP}:${Port}",

        [int]$TimeoutSeconds = 300,

        [int]$PollIntervalSeconds = 5
    )

    Write-Host "  Waiting for $Name (${IP}:${Port})..." -NoNewline
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        $tcp = $null
        try {
            $tcp = [System.Net.Sockets.TcpClient]::new()
            if ($tcp.ConnectAsync($IP, $Port).Wait(3000) -and $tcp.Connected) {
                Write-Host " ready." -ForegroundColor Green
                return
            }
        }
        catch {
            Write-Verbose "Connection attempt to ${IP}:${Port} failed: $($_.Exception.Message)"
        }
        finally {
            if ($tcp) { $tcp.Dispose() }
        }
        Start-Sleep -Seconds $PollIntervalSeconds
    }

    Write-Host " TIMEOUT" -ForegroundColor Red
    throw "$Name at ${IP}:${Port} not reachable after $TimeoutSeconds seconds."
}
