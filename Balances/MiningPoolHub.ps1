using module ..\Include.psm1

param($Config)
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$MyConfig = $Config.Pools.$Name

$Request = [PSCustomObject]@{}

if(!$MyConfig.API_Key) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no API key specified."
    return
}

# Get user balances
try {
    $Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($MyConfig.API_Key)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
}

if (($Request.getuserallbalances.data | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

# Get exchange rates
try {
    $ExchangeRates = (Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop).Return
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}


# MiningPoolHub does balances a little differently from everyone else, returning the altcoin values directly
# until they are exchanged. Convert them to pending BTC values
$altcointotal = [double]0
$Request.getuserallbalances.data | Foreach-Object {
    if($_.coin -eq 'bitcoin') {
        $balance = $_
    } else {
        # Get value of altcoin in BTC
        $coinname = $_.coin
        [Double]$ExchangeRate = ($ExchangeRates | Where-Object {$_.coin_name -eq $coinname}).highest_buy_price
        $altcointotal += ($_.confirmed + $_.unconfirmed + $balance.ae_confirmed + $_.ae_unconfirmed + $_.exchange) * $Exchangerate
    }
}

[PSCustomObject]@{
    'currency' = 'BTC'
    'balance' = $balance.confirmed
    'pending' = $balance.unconfirmed + $balance.ae_confirmed + $balance.ae_unconfirmed + $balance.exchange + $altcointotal
    'total' = $balance.confirmed + $balance.unconfirmed + $balance.ae_confirmed + $balance.ae_unconfirmed + $balance.exchange + $altcointotal
    'lastupdated' = (Get-Date).ToUniversalTime()
}