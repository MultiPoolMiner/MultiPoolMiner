using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC", "DASH")

$PoolRegions = "eu", "jp", "na", "sea"
$PoolAPIStatusUri = "https://www.zpool.ca/api/status"
$PoolAPICurrenciesUri = "https://www.zpool.ca/api/currencies"

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIStatusRequest -and $APICurrenciesRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIStatusRequest) {$APIStatusRequest = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $APICurrenciesRequest) {Start-Sleep 10 <#Temp fix: workaround for Zpool(Coins) anti-DDoS protect (pool allows only 6 API calls per minute)#>; $APICurrenciesRequest = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--        
    }
}

if (-not ($APIStatusRequest -and $APICurrenciesRequest)) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($APIStatusRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [StatusUri] returned nothing. "
    return
}

if (($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [CurrenciesUri] returned nothing. "
    return
}

$Payout_Currencies = ($Payout_Currencies + @($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object {$Config.Pools.$Name.Wallets.$_} | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$APIStatusRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APIStatusRequest.$_.hashrate -GT 0} | ForEach-Object {

    $PoolHost       = "mine.zpool.ca"
    $Port           = $APIStatusRequest.$_.port
    $Algorithm      = $APIStatusRequest.$_.name
    $CoinName       = Get-CoinName $(if ($APIStatusRequest.$_.coins -eq 1) {$APICurrenciesRequest.$($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesRequest.$_.algo -eq $Algorithm}).Name})
    $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
    if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
    $Workers        = $APIStatusRequest.$_.workers
    $Fee            = $APIStatusRequest.$_.Fees / 100

    $Divisor = 1000000 * [Double]$APIStatusRequest.$_.mbtc_mh_factor

    if ((Get-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusRequest.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusRequest.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $PoolRegions | ForEach-Object {
        $Region = $_
        $Region_Norm = Get-Region $Region

        $Payout_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $Algorithm_Norm
                CoinName      = $CoinName
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Algorithm).$($Region).$($PoolHost)"
                Port          = $Port
                User          = $Config.Pools.$Name.Wallets.$_
                Pass          = "$($Config.Pools.$Name.Worker),c=$_"
                Region        = $Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                Fee           = $Fee
                Workers       = [Int]$Workers
            }
        }
    }
}
