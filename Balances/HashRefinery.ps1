using module ..\Include.psm1

param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (-not $PoolConfig.Wallets.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIRequest) {$APIRequest = Invoke-RestMethod "http://pool.hashrefinery.com/api/wallet?address=$($PoolConfig.Wallets.BTC)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
    }
    $RetryCount--
}

if (-not $APIRequest) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($APIRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
    Name        = "$($Name) ($($APIRequest.currency))"
    Pool        = $Name
    Currency    = $APIRequest.currency
    Balance     = $APIRequest.balance
    Pending     = $APIRequest.unsold
    Total       = $APIRequest.unpaid
    Lastupdated = (Get-Date).ToUniversalTime()
}