using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PoolRegions = "europe"
$PoolAPIStatusUri = "http://api.zergpool.com:8080/api/status"
$PoolAPICurrenciesUri = "http://api.zergpool.com:8080/api/currencies"

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC", "DASH")

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
    $APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesRequest.$_.hashrate -gt 0} | Foreach-Object {
     
        $Algorithm = $APICurrenciesRequest.$_.algo
        $CoinName = Get-CoinName $APICurrenciesRequest.$_.name

        $Divisor = 1000000000 * [Double]$APICurrenciesRequest.$_.mbtc_mh_factor
        if ($Divisor -eq 0) {
            Write-Log -Level Info "$($Name): Unable to determine divisor for coin $CoinName and algorithm $Algorithm. "
            return
        }
        else {
            $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
            if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
            if ($Algorithm_Norm -eq $Algorithm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
            if ($Algorithm_Norm -match "Equihash1445|Equihash1927") {$CoinName = "ManagedByPool"}

            $PoolHost       = "mine.zergpool.com"
            $Port           = $APICurrenciesRequest.$_.port
            $MiningCurrency = $_ -split "-" | Select-Object -Index 0
            $Workers        = $APICurrenciesRequest.$_.workers
            $Fee            = if ($APIStatusRequest.$Algorithm) {$APIStatusRequest.$Algorithm.Fees / 100} else {5 / 100}

            $Stat = Set-Stat -Name "$($Name)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesRequest.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

            $PoolRegions | ForEach-Object {
                $Region = $_
                $Region_Norm = Get-Region $Region

                if ($($Config.Pools.$Name.Wallets).$MiningCurrency) {
                    #Option 3
                    [PSCustomObject]@{
                        Algorithm      = $Algorithm_Norm
                        CoinName       = $CoinName
                        Price          = $Stat.Live
                        StablePrice    = $Stat.Week
                        MarginOfError  = $Stat.Week_Fluctuation
                        Protocol       = "stratum+tcp"
                        Host           = "$($Algorithm).$($PoolHost)"
                        Port           = $Port
                        User           = $Config.Pools.$Name.Wallets.$_
                        Pass           = "$($Config.Pools.$Name.Worker),c=$($_),mc=$MiningCurrency$($Config.Pools.$Name.PasswordSuffix.Algorithm."*")$($Config.Pools.$Name.PasswordSuffix.Algorithm.$Algorithm_Norm)$($Config.Pools.$Name.PasswordSuffix.CoinName."*")$($Config.Pools.$Name.PasswordSuffix.CoinName.$CoinName)"
                        Region         = $Region_Norm
                        SSL            = $false
                        Updated        = $Stat.Updated
                        Fee            = $Fee
                        Workers        = [Int]$Workers
                        MiningCurrency = $MiningCurrency
                    }
                }
                elseif ($APICurrenciesRequest.$MiningCurrency.noautotrade -eq 0) {
                    $Payout_Currencies | ForEach-Object {
                        #Option 2
                        [PSCustomObject]@{
                            Algorithm      = $Algorithm_Norm
                            CoinName       = $CoinName
                            Price          = $Stat.Live
                            StablePrice    = $Stat.Week
                            MarginOfError  = $Stat.Week_Fluctuation
                            Protocol       = "stratum+tcp"
                            Host           = "$Algorithm.$PoolHost"
                            Port           = $Port
                            User           = $Config.Pools.$Name.Wallets.$_
                            Pass           = "$($Config.Pools.$Name.Worker),c=$($_),mc=$MiningCurrency$($Config.Pools.$Name.PasswordSuffix.Algorithm."*")$($Config.Pools.$Name.PasswordSuffix.Algorithm.$Algorithm_Norm)$($Config.Pools.$Name.PasswordSuffix.CoinName."*")$($Config.Pools.$Name.PasswordSuffix.CoinName.$CoinName)"
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
}
else {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
}
