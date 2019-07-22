using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not ($Config.Pools.$Name.Wallets | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) -ne "BTC") {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$PoolRegions = "asia", "eu", "us"
$PoolAPIStatusUri = "http://www.phi-phi-pool.com/api/status"
$PoolAPICurrenciesUri = "http://www.phi-phi-pool.com/api/currencies"

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
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [StatusUri] returned nothing. "
    return
}

if (($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [CurrenciesUri] returned nothing. "
    return
}

#Pool does not do auto conversion to BTC
$Payout_Currencies = @($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Where-Object {$Config.Pools.$Name.Wallets.$_} | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesResponse.$_.hashrate -gt 0} | Foreach-Object {
 
    $Algorithm = $APICurrenciesResponse.$_.algo

    # Not all algorithms are always exposed in API
    if ($APIStatusResponse.$Algorithm) {
    
        $APICurrenciesResponse.$_ | Add-Member Symbol $_ -ErrorAction SilentlyContinue

        $CoinName       = Get-CoinName $APICurrenciesResponse.$_.name
        $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
        if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
        $PoolHost       = "phi-phi-pool.com"
        $Port           = $APICurrenciesResponse.$_.port
        $MiningCurrency = $APICurrenciesResponse.$_.symbol
        $Workers        = $APICurrenciesResponse.$_.workers
        $Fee            = $APIStatusResponse.$Algorithm.Fees / 100

        $Divisor = 1000000000 * [Double]$APIStatusResponse.$Algorithm.mbtc_mh_factor

        $Stat = Set-Stat -Name "$($Name)_$($CoinName)_Profit" -Value ([Double]$APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

        try {
            $EstimateCorrection = ($APIStatusResponse.$Algorithm.actual_last24h / 1000) / $APIStatusResponse.$Algorithm.estimate_last24h
        }
        catch {}

        $PoolRegions | ForEach-Object {
            $Region = $_
            $Region_Norm = Get-Region $Region

            [PSCustomObject]@{
                Algorithm          = $Algorithm_Norm
                CoinName           = $CoinName
                Price              = $Stat.Live
                StablePrice        = $Stat.Week
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+tcp"
                Host               = "$Region.$PoolHost"
                Port               = $Port
                User               = $Config.Pools.$Name.Wallets.$MiningCurrency
                Pass               = "c=$MiningCurrency"
                Region             = $Region_Norm
                SSL                = $false
                Updated            = $Stat.Updated
                Fee                = $Fee
                Workers            = [Int]$Workers
                MiningCurrency     = $MiningCurrency
                EstimateCorrection = $EstimateCorrection
            }
        }
    }
}
