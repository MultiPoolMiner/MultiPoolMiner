using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$Request = [PSCustomObject]@{}

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

try {
    
    #NH API does not total all of your balances for each algo up, so you have to do it with another call then total them manually.
    $UnpaidRequest = Invoke-RestMethod "https://api.nicehash.com/api?method=stats.provider&addr=$($PoolConfig.BTC)"  -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

    $sum = 0
    $UnpaidRequest.result.stats.balance | Foreach { $sum += $_}

}
catch {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
}

[PSCustomObject]@{
    "currency" = 'BTC'
    "balance" = $sum
    "pending" = 0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
    "total" = $sum
    'lastupdated' = (Get-Date).ToUniversalTime()
}