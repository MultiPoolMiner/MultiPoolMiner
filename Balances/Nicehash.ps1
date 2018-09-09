using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Request = [PSCustomObject]@{}

try {
    #NH API does not total all of your balances for each algo up, so you have to do it with another call then total them manually.
    $UnpaidRequest = Invoke-RestMethod "https://api.nicehash.com/api?method=stats.provider&addr=$($PoolConfig.BTC)"  -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

    $Sum = 0
    $UnpaidRequest.result.stats.balance | Foreach {$Sum += $_}
}
catch {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

[PSCustomObject]@{
    Name        = "$($Name) (BTC)"
    Pool        = $Name
    Currency    = "BTC"
    Balance     = $Sum
    Pending     = 0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
    Total       = $Sum
    LastUpdated = (Get-Date).ToUniversalTime()
}