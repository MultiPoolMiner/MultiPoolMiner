using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$PoolName = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC") | Where-Object {$Config.Pools.$PoolName.Wallets.$_}
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no wallet address specified. "
    return
}

$PoolRegions = "europe"
$PoolAPIStatusUri = "https://www.nlpool.nl/api/status"
$PoolAPICurrenciesUri = "https://www.nlpool.nl/api/currencies"

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIStatusResponse -and $APICurrenciesResponse) -and $RetryCount -gt 0) {
    try {
        if (-not $APIStatusResponse) {$APIStatusResponse = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $APICurrenciesResponse) {$APICurrenciesResponse  = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--        
    }
}

if (-not ($APIStatusResponse -and $APICurrenciesResponse)) {
    Write-Log -Level Warn "Pool API ($PoolName) has failed. "
    return
}

if (($APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($PoolName) [StatusUri] returned nothing. "
    return
}

if (($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($PoolName) [CurrenciesUri] returned nothing. "
    return
}

$Payout_Currencies = (@($Payout_Currencies) + @($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object {$Config.Pools.$PoolName.Wallets.$_} | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no wallet address specified. "
    return
}

Write-Log -Level Verbose "Processing pool data ($PoolName). "
$APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APIStatusResponse.$_.hashrate -GT 0} | ForEach-Object {

    $PoolHost       = "mine.nlpool.nl"
    $Port           = $APIStatusResponse.$_.port
    $Algorithm      = $APIStatusResponse.$_.name
    $CoinName       = Get-CoinName $(if ($APIStatusResponse.$_.coins -eq 1) {$APICurrenciesResponse.$($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesResponse.$_.algo -eq $Algorithm}).Name})
    $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
    if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
    if ($Algorithm_Norm -match "Equihash1445|Equihash1927") {$CoinName = "ManagedByPool"}
    $Workers        = $APIStatusResponse.$_.workers
    $Fee            = $APIStatusResponse.$_.Fees / 100

    $Divisor = 1000000 * [Double]$APIStatusResponse.$_.mbtc_mh_factor

    # switch ($Algorithm_Norm) {
    #     "Yescrypt" {$Divisor *= 100} #temp fix
    # }

    if ((Get-Stat -Name "$($PoolName)_$($Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($PoolName)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($PoolName)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    try {
        $EstimateCorrection = ($APIStatusResponse.$_.actual_last24h / 1000) / $APIStatusResponse.$_.estimate_last24h
    }
    catch {}

    $PoolRegions | ForEach-Object {
        $Region = $_
        $Region_Norm = Get-Region $Region

        $Payout_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm          = $Algorithm_Norm
                CoinName           = $CoinName
                Price              = $Stat.Live
                StablePrice        = $Stat.Week
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+tcp"
                Host               = "$PoolHost"
                Port               = $Port
                User               = $Config.Pools.$PoolName.Wallets.$_
                Pass               = "$($Config.Pools.$PoolName.Worker),c=$_"
                Region             = $Region_Norm
                SSL                = $false
                Updated            = $Stat.Updated
                Fee                = $Fee
                Workers            = [Int]$Workers
                EstimateCorrection = $EstimateCorrection
            }
        }
    }
}
