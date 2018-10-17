using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$NLPool_Request = [PSCustomObject]@{}

try {
    $NLPool_Request = Invoke-RestMethod "http://www.nlpool.nl/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $NLPoolCoins_Request = Invoke-RestMethod "http://www.nlpool.nl/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($NLPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$NLPool_Regions = "europe"
$NLpool_Currencies = @("BTC", "LTC") + ($NLPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$NLPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$NLPool_Request.$_.hashrate -gt 0} | ForEach-Object {
    $NLPool_Host = "mine.nlpool.nl"
    $NLPool_Port = $NLPool_Request.$_.port
    $NLPool_Algorithm = $NLPool_Request.$_.name
    $NLPool_Algorithm_Norm = Get-Algorithm $NLPool_Algorithm
    $NLPool_Coin = ""

    $Divisor = 1000000 * [Double]$NLPool_Request.$_.mbtc_mh_factor

    switch ($NLPool_Algorithm_Norm) {
        "Yescrypt" {$Divisor *= 100}       #temp fix

    }

    if ((Get-Stat -Name "$($Name)_$($NLPool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($NLPool_Algorithm_Norm)_Profit" -Value ([Double]$NLPool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($NLPool_Algorithm_Norm)_Profit" -Value ([Double]$NLPool_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $NLPool_Regions | ForEach-Object {
        $NLPool_Region = $_
        $NLPool_Region_Norm = Get-Region $NLPool_Region

        $NLPool_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $NLPool_Algorithm_Norm
                CoinName      = $NLPool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$NLPool_Host"
                Port          = $NLPool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $NLPool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
