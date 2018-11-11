using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$RetryCount = 3
$RetryDelay = 2
while (-not ($YiiMP_Request -and $YiiMPCoins_Request) -and $RetryCount -gt 0) {
    try {
        if (-not $YiiMP_Request) {$YiiMP_Request = Invoke-RestMethod "http://api.yiimp.eu/api/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $YiiMPCoins_Request) {$YiiMPCoins_Request = Invoke-RestMethod "http://api.yiimp.eu/api/currencies" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
        $RetryCount--        
    }
}

if (-not $YiiMP_Request) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($YiiMPCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$YiiMP_Regions = "us"
$YiiMP_Currencies = ($YiiMPCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

if (-not $YiiMP_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$YiiMP_Currencies | Where-Object {$YiiMPCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $YiiMP_Host = "yiimp.eu"
    $YiiMP_Port = $YiiMPCoins_Request.$_.port
    $YiiMP_Algorithm = $YiiMPCoins_Request.$_.algo
    $YiiMP_Algorithm_Norm = Get-Algorithm $YiiMP_Algorithm
    $YiiMP_Coin = $YiiMPCoins_Request.$_.name
    $YiiMP_Currency = $_

    $Divisor = 1000000000 * [Double]$YiiMP_Request.$YiiMP_Algorithm.mbtc_mh_factor

    $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$YiiMPCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $YiiMP_Regions | ForEach-Object {
        $YiiMP_Region = $_
        $YiiMP_Region_Norm = Get-Region $YiiMP_Region

        [PSCustomObject]@{
            Algorithm     = $YiiMP_Algorithm_Norm
            CoinName      = $YiiMP_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $YiiMP_Host
            Port          = $YiiMP_Port
            User          = Get-Variable $YiiMP_Currency -ValueOnly
            Pass          = "$Worker,c=$YiiMP_Currency"
            Region        = $YiiMP_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PayoutScheme  = "PPLNS"
        }
    }
}
