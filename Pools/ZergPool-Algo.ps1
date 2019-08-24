using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$PoolFileName = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolRegions = "europe"
$PoolAPIStatusUri = "http://api.zergpool.com:8080/api/status"
$PoolAPICurrenciesUri = "http://api.zergpool.com:8080/api/currencies"
$RetryCount = 3
$RetryDelay = 2

$PoolName = $PoolFileName -split "-" | Select-Object -First 1
$PoolNameAlgo = "$($PoolName)-Algo"
$PoolNameCoin = "$($PoolName)-Coin"
$PoolNames = @(@($PoolNameAlgo, $PoolNameCoin) | Where-Object {((Test-Path "Pools\$_.ps1" -PathType Leaf -ErrorAction SilentlyContinue) -and (-not $Config.PoolName -or $Config.PoolName -contains $_ -and $Config.ExcludePoolName -notcontains $_))})

$PoolNames | ForEach-Object {
    $PoolName = $_

    #*-Coin quits immediately if both files (*-Coin and *-Algo) exist in pool dir. One pool file works for both kinds.
    if ($PoolNames.Count -eq 2 -and $PoolFileName -contains $PoolNameCoin) {Exit}

    # Guaranteed payout currencies
    $Payout_Currencies = @("BCH", "BTC", "LTC", "DASH") | Where-Object {$Config.Pools.$PoolName.Wallets.$_}
    if (-not $Payout_Currencies) {
        Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no wallet address specified. "
        break
    }

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
        break
    }

    if (($APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
        Write-Log -Level Warn "Pool API ($PoolName) [StatusUri] returned nothing. "
        break
    }

    if (($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
        Write-Log -Level Warn "Pool API ($PoolName) [CurrenciesUri] returned nothing. "
        break
    }

    $Payout_Currencies = (@($Payout_Currencies) + @($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object {$Config.Pools.$PoolName.Wallets.$_} | Sort-Object -Unique
    if (-not $Payout_Currencies) {
        Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no wallet address specified. "
        break
    }

    if ($PoolName -eq $PoolNameAlgo) {
        Write-Log -Level Verbose "Processing pool data ($PoolName). "
        $APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APIStatusResponse.$_.hashrate -GT 0} | ForEach-Object {

            $PoolHost       = "mine.zergpool.com"
            $Port           = $APIStatusResponse.$_.port
            $Algorithm      = $APIStatusResponse.$_.name
            $CoinName       = Get-CoinName $(if ($APIStatusResponse.$_.coins -eq 1) {$APICurrenciesResponse.$($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesResponse.$_.algo -eq $Algorithm}).Name})
            $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
            if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
            if ($Algorithm_Norm -match "Equihash1445|Equihash1927") {$CoinName = "ManagedByPool"}
            $Workers        = $APIStatusResponse.$_.workers
            $Fee            = $APIStatusResponse.$_.Fees / 100

            $Divisor = 1000000 * [Double]$APIStatusResponse.$_.mbtc_mh_factor
            if ($Divisor -eq 0) {
                Write-Log -Level Info "$($PoolName): Unable to determine divisor for algorithm $Algorithm. "
                break
            }
            else {
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
                            Name               = $PoolName
                            Algorithm          = $Algorithm_Norm
                            CoinName           = $CoinName
                            Price              = $Stat.Live
                            StablePrice        = $Stat.Week
                            MarginOfError      = $Stat.Week_Fluctuation
                            Protocol           = "stratum+tcp"
                            Host               = "$($Algorithm).$($PoolHost)"
                            Port               = $Port
                            User               = $Config.Pools.$PoolName.Wallets.$_
                            Pass               = "$($Config.Pools.$PoolName.Worker),c=$($_)$($Config.Pools.$PoolName.PasswordSuffix.Algorithm."*")$($Config.Pools.$PoolName.PasswordSuffix.Algorithm.$Algorithm_Norm)"
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
        }
    }

    if ($PoolName -eq $PoolNameCoin) {
        Write-Log -Level Verbose "Processing pool data ($PoolName). "
        $APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesResponse.$_.hashrate -gt 0} | ForEach-Object {
        
            $Algorithm = $APICurrenciesResponse.$_.algo
            $CoinName = Get-CoinName $APICurrenciesResponse.$_.name

            $Divisor = 1000000000 * [Double]$APICurrenciesResponse.$_.mbtc_mh_factor
            if ($Divisor -eq 0) {
                Write-Log -Level Info "$($PoolName): Unable to determine divisor for coin $CoinName and algorithm $Algorithm. "
                break
            }
            else {
                $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
                if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
                if ($Algorithm_Norm -match "Equihash1445|Equihash1927") {$CoinName = "ManagedByPool"}

                $PoolHost       = "mine.zergpool.com"
                $Port           = $APICurrenciesResponse.$_.port
                $MiningCurrency = $_ -split "-" | Select-Object -Index 0
                $Workers        = $APICurrenciesResponse.$_.workers
                $Fee            = if ($APIStatusResponse.$Algorithm) {$APIStatusResponse.$Algorithm.Fees / 100} else {5 / 100}

                $Stat = Set-Stat -Name "$($PoolName)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
                $Stat = Set-Stat -Name "$($PoolName)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

                try {
                    $EstimateCorrection = ($APIStatusResponse.$Algorithm.actual_last24h / 1000) / $APIStatusResponse.$Algorithm.estimate_last24h
                }
                catch {}

                $PoolRegions | ForEach-Object {
                    $Region = $_
                    $Region_Norm = Get-Region $Region

                    if ($($Config.Pools.$PoolName.Wallets).$MiningCurrency) {
                        #Option 3
                        [PSCustomObject]@{
                            Name               = $PoolName
                            Algorithm          = $Algorithm_Norm
                            CoinName           = $CoinName
                            Price              = $Stat.Live
                            StablePrice        = $Stat.Week
                            MarginOfError      = $Stat.Week_Fluctuation
                            Protocol           = "stratum+tcp"
                            Host               = "$($Algorithm).$($PoolHost)"
                            Port               = $Port
                            User               = $Config.Pools.$PoolName.Wallets.$_
                            Pass               = "$($Config.Pools.$PoolName.Worker),c=$($_),mc=$MiningCurrency$($Config.Pools.$PoolName.PasswordSuffix.Algorithm."*")$($Config.Pools.$PoolName.PasswordSuffix.Algorithm.$Algorithm_Norm)$($Config.Pools.$PoolName.PasswordSuffix.CoinName."*")$($Config.Pools.$PoolName.PasswordSuffix.CoinName.$CoinName)"
                            Region             = $Region_Norm
                            SSL                = $false
                            Updated            = $Stat.Updated
                            Fee                = $Fee
                            Workers            = [Int]$Workers
                            MiningCurrency     = $MiningCurrency
                            EstimateCorrection = $EstimateCorrection
                        }
                    }
                    elseif ($APICurrenciesResponse.$MiningCurrency.noautotrade -eq 0) {
                        $Payout_Currencies | ForEach-Object {
                            #Option 2
                            [PSCustomObject]@{
                                Name               = $PoolName
                                Algorithm          = $Algorithm_Norm
                                CoinName           = $CoinName
                                Price              = $Stat.Live
                                StablePrice        = $Stat.Week
                                MarginOfError      = $Stat.Week_Fluctuation
                                Protocol           = "stratum+tcp"
                                Host               = "$Algorithm.$PoolHost"
                                Port               = $Port
                                User               = $Config.Pools.$PoolName.Wallets.$_
                                Pass               = "$($Config.Pools.$PoolName.Worker),c=$($_),mc=$MiningCurrency$($Config.Pools.$PoolName.PasswordSuffix.Algorithm."*")$($Config.Pools.$PoolName.PasswordSuffix.Algorithm.$Algorithm_Norm)$($Config.Pools.$PoolName.PasswordSuffix.CoinName."*")$($Config.Pools.$PoolName.PasswordSuffix.CoinName.$CoinName)"
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
            }
        }
    }
}
