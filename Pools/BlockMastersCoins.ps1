using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PoolRegions = "eu", "us"
$PoolAPIStatusUri = "http://blockmasters.co/api/status"
$PoolAPICurrenciesUri = "http://blockmasters.co/api/currencies"

# Guaranteed Payout currencies
$Payout_Currencies = @("BTC", "DOGE", "LTC")

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIStatusRequest -and $APICurrenciesRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIStatusRequest) {$APIStatusRequest = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue}
        if (-not $APICurrenciesRequest) {$APICurrenciesRequest  = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--        
    }
}

if (-not $APIStatusRequest) {
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

$Payout_Currencies = ($Payout_Currencies + @($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Sort-Object | Select-Object -Unique | Where-Object {$Config.Pools.$Name.Wallets.$_}

if ($Payout_Currencies) {
    $APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesRequest.$_.hashrate -GT 0} | Foreach-Object {

        $Algorithm = $APICurrenciesRequest.$_.algo

        # Not all algorithms are always exposed in API
        if ($APIStatusRequest.$Algorithm) {

            $CoinName       = Get-CoinName $APICurrenciesRequest.$_.name
            $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
            if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}

            $PoolHost       = "blockmasters.co"
            $Port           = $APICurrenciesRequest.$_.port
            $MiningCurrency = $_ -split "-" | Select-Object -Index 0
            $Workers        = $APICurrenciesRequest.$_.workers
            $Fee            = $APIStatusRequest.$Algorithm.Fees / 100

            $Divisor = 1000000000 * [Double]$APIStatusRequest.$Algorithm.mbtc_mh_factor

            $Stat = Set-Stat -Name "$($Name)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesRequest.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

            $PoolRegions | ForEach-Object {
                $Region = $_
                $Region_Norm = Get-Region $Region

                $Payout_Currencies | ForEach-Object {
                    [PSCustomObject]@{
                        Algorithm      = $Algorithm_Norm
                        CoinName       = $CoinName
                        Price          = $Stat.Live
                        StablePrice    = $Stat.Week
                        MarginOfError  = $Stat.Week_Fluctuation
                        Protocol       = "stratum+tcp"
                        Host           = "$(if ($Region -eq "eu") {"eu."})$PoolHost"
                        Port           = $Port
                        User           = $Config.Pools.$Name.Wallets.$_
                        Pass           = "$($Config.Pools.$Name.Worker),c=$_"
                        Region         = $Region_Norm
                        SSL            = $false
                        Updated        = $Stat.Updated
                        Fee            = $Fee
                        Workers        = [Int]$Workers
                        MiningCurrency = $MiningCurrency
                    }
                }
            }
        }
    }
}
else { 
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
}

