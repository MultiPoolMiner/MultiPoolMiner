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
while (-not ($Zpool_Request -and $ZpoolCoins_Request) -and $RetryCount -gt 0) {
    try {
        if (-not $Zpool_Request) {$Zpool_Request = Invoke-RestMethod "https://www.zpool.ca/api/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $ZpoolCoins_Request) {$ZpoolCoins_Request = Invoke-RestMethod "https://www.zpool.ca/api/currencies" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
        $RetryCount--        
    }
}

if (-not $Zpool_Request) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Zpool_Regions = "eu", "na", "sea" #STRATUM SERVERS - North America <na> - Europe <eu> - South East Asia <sea>
$Zpool_Currencies = @("BTC") + ($ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

if (-not $Zpool_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Zpool_Request.$_.hashrate -gt 0} |ForEach-Object {
    $Zpool_Host = "mine.zpool.ca"
    $Zpool_Port = $Zpool_Request.$_.port
    $Zpool_Algorithm = $Zpool_Request.$_.name
    $Zpool_Algorithm_Norm = Get-Algorithm $Zpool_Algorithm
    $Zpool_Coin = ""
    
    $Divisor = 1000000 * [Double]$Zpool_Request.$_.mbtc_mh_factor

    if ((Get-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $Zpool_Regions | ForEach-Object {
        $Zpool_Region = $_
        $Zpool_Region_Norm = Get-Region $Zpool_Region

        $Zpool_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $Zpool_Algorithm_Norm
                CoinName      = $Zpool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Zpool_Algorithm).$($Zpool_Region).$($Zpool_Host)"
                Port          = $Zpool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $Zpool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PayoutScheme  = "PPLNS"
            }
        }
    }
}
