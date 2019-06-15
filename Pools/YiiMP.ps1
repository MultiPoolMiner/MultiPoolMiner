using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PoolRegions = "us"
$PoolAPIStatusUri = "http://api.yiimp.eu/api/status"
$PoolAPICurrenciesUri = "http://api.yiimp.eu/api/currencies"

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIStatusRequest -and $APICurrenciesRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIStatusRequest) {$APIStatusRequest = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $APICurrenciesRequest) {$APICurrenciesRequest  = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
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

#Pool allows payout in any currency available in API
if ($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Sort-Object | Select-Object -Unique | Where-Object {$Config.Pools.$Name.Wallets.$_}) {
    $APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Sort-Object | Select-Object -Unique | Where-Object {$APICurrenciesRequest.$_.hashrate -GT 0 -and $Config.Pools.$Name.Wallets.$_} | Foreach-Object {

        $MiningCurrency = $APICurrenciesRequest.$_.symbol
        if ($Config.Pools.$Name.Wallets.$MiningCurrency) {
            $APICurrenciesRequest.$_ | Add-Member Symbol $_ -ErrorAction SilentlyContinue

            $PoolHost       = "yiimp.eu"
            $Port           = $APICurrenciesRequest.$_.port
            $Algorithm      = $APICurrenciesRequest.$_.algo
            $CoinName       = Get-CoinName $(if ($APIStatusRequest.$_.coins -eq 1) {$APICurrenciesRequest.$($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesRequest.$_.algo -eq $Algorithm}).Name})
            $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
            if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}

            $MiningCurrency = $APICurrenciesRequest.$_.symbol
            $Workers        = $APICurrenciesRequest.$_.workers
            $Fee            = $APIStatusRequest.$Algorithm.Fees / 100

            $Divisor = 1000000 * [Double]$APIStatusRequest.$Algorithm.mbtc_mh_factor

            $Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesRequest.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

            $PoolRegions | ForEach-Object {
                $Region = $_
                $Region_Norm = Get-Region $Region

                [PSCustomObject]@{
                    Algorithm      = $Algorithm_Norm
                    CoinName       = $CoinName
                    Price          = $Stat.Live
                    StablePrice    = $Stat.Week
                    MarginOfError  = $Stat.Week_Fluctuation
                    Protocol       = "stratum+tcp"
                    Host           = $PoolHost
                    Port           = $Port
                    User           = $Config.Pools.$Name.Wallets.$MiningCurrency
                    Pass           = "$($Config.Pools.$Name.Worker),c=$MiningCurrency"
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
else { 
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
}
