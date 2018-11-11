using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$RetryCount = 3
$RetryDelay = 2
while (-not ($BlazePool_Request) -and $RetryCount -gt 0) {
    try {
        if (-not $BlazePool_Request) {$BlazePool_Request = Invoke-RestMethod "http://api.blazepool.com/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
        $RetryCount--        
    }
}

if (-not $BlazePool_Request) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BlazePool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$BlazePool_Regions = "us"
$BlazePool_Currencies = @("BTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

if (-not $BlazePool_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$BlazePool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$BlazePool_Request.$_.hashrate -gt 0 -and [Double]$BlazePool_Request.$_.estimate_current  -gt 0} | ForEach-Object {
    $BlazePool_Host = "$_.mine.blazepool.com"
    $BlazePool_Port = $BlazePool_Request.$_.port
    $BlazePool_Algorithm = $BlazePool_Request.$_.name
    $BlazePool_Algorithm_Norm = Get-Algorithm $BlazePool_Algorithm
    $BlazePool_Coin = ""

    $Divisor = 1000000 * [Double]$BlazePool_Request.$_.mbtc_mh_factor
    
    if ((Get-Stat -Name "$($Name)_$($BlazePool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($BlazePool_Algorithm_Norm)_Profit" -Value ([Double]$BlazePool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($BlazePool_Algorithm_Norm)_Profit" -Value ([Double]$BlazePool_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $BlazePool_Regions | ForEach-Object {
        $BlazePool_Region = $_
        $BlazePool_Region_Norm = Get-Region $BlazePool_Region

        $BlazePool_Currencies | Where-Object {Get-Variable $_ -ValueOnly} | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $BlazePool_Algorithm_Norm
                CoinName      = $BlazePool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $BlazePool_Host
                Port          = $BlazePool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "ID=$Worker,c=$_"
                Region        = $BlazePool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PayoutScheme  = "PPLNS"
            }
        }
    }
}
