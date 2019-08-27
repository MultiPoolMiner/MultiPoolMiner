using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config #to be removed
)

$PoolFileName = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolRegions = "europe"
$PoolAPIStatusUri = "http://api.zergpool.com:8080/api/status"
$PoolAPICurrenciesUri = "http://api.zergpool.com:8080/api/currencies"
$RetryCount = 3
$RetryDelay = 2

$Wallets = $Config.Pools.$PoolFileName.Wallets #to be removed
$Worker = $Config.Pools.$PoolFileName.Worker #to be removed
$PasswordSuffix = $Config.Pools.$PoolName.PasswordSuffix #to be removed

# Guaranteed payout currencies
$Payout_Currencies = @("BCH", "BTC", "LTC", "DASH") | Where-Object { $Wallets.$_ }
#if (-not $Payout_Currencies) {
#    Write-Log -Level Verbose "Cannot mine on pool ($PoolFileName) - no wallet address specified. "
#    return
#}

while (-not ($APIStatusResponse -and $APICurrenciesResponse) -and $RetryCount -gt 0) {
    try {
        if (-not $APIStatusResponse) { $APIStatusResponse = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop }
        if (-not $APICurrenciesResponse) { $APICurrenciesResponse = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop }
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--
    }
}

if (-not ($APIStatusResponse -and $APICurrenciesResponse)) {
    Write-Log -Level Warn "Pool API ($PoolFileName) has failed. "
    return
}

if (($APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($PoolFileName) [StatusUri] returned nothing. "
    return
}

if (($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($PoolFileName) [CurrenciesUri] returned nothing. "
    return
}

$Payout_Currencies = (@($Payout_Currencies) + @($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object { $Wallets.$_ } | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($PoolFileName) - no wallet address specified. "
    return
}

Write-Log -Level Verbose "Processing pool data ($PoolFileName). "
$APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $APIStatusResponse.$_.hashrate -gt 0 } | Where-Object { $APIStatusResponse.$_.mbtc_mh_factor -gt 0 } | ForEach-Object {
    $PoolHost = "mine.zergpool.com"
    $Port = $APIStatusResponse.$_.port
    $Algorithm = $APIStatusResponse.$_.name
    $CoinName = Get-CoinName $(if ($APIStatusResponse.$_.coins -eq 1) { $APICurrenciesResponse.$($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $APICurrenciesResponse.$_.algo -eq $Algorithm }).Name })
    $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
    if (-not $Algorithm_Norm) { $Algorithm_Norm = Get-Algorithm $Algorithm }
    $Workers = $APIStatusResponse.$_.workers
    $Fee = $APIStatusResponse.$_.Fees / 100

    $Divisor = 1000000 <#check#> * [Double]$APIStatusResponse.$_.mbtc_mh_factor

    if ($Divisor -eq 0) {
        Write-Log -Level Info "$($PoolFileName): Unable to determine divisor for algorithm $Algorithm. "
    }
    else {
        if ((Get-Stat -Name "$($PoolFileName)_$($Algorithm_Norm)_Profit") -eq $null) { $Stat = Set-Stat -Name "$($PoolFileName)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1) }
        else { $Stat = Set-Stat -Name "$($PoolFileName)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true }

        try {
            $EstimateCorrection = ($APIStatusResponse.$_.actual_last24h / 1000) / $APIStatusResponse.$_.estimate_last24h
        }
        catch { }

        $PoolRegions | ForEach-Object {
            $Region = $_
            $Region_Norm = Get-Region $Region

            $Payout_Currencies | ForEach-Object {
                #Option 1
                [PSCustomObject]@{
                    Name               = "$PoolFileName-Algo"
                    Algorithm          = $Algorithm_Norm
                    CoinName           = $CoinName
                    Price              = $Stat.Live
                    StablePrice        = $Stat.Week
                    MarginOfError      = $Stat.Week_Fluctuation
                    Protocol           = "stratum+tcp"
                    Host               = "$Algorithm.$PoolHost"
                    Port               = $Port
                    User               = $Wallets.$_
                    Pass               = "ID=$Worker,c=$_$($PasswordSuffix.Algorithm."*")$($PasswordSuffix.Algorithm.$Algorithm_Norm)"
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

Write-Log -Level Verbose "Processing pool data ($PoolFileName). "
$APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $APICurrenciesResponse.$_.hashrate -gt 0 } | ForEach-Object {
    $APICurrenciesResponse.$_ | Add-Member Symbol $_ -ErrorAction Ignore

    $Algorithm = $APICurrenciesResponse.$_.algo

    # Not all algorithms are always exposed in API
    if ($APIStatusResponse.$Algorithm -and $APIStatusResponse.$Algorithm.mbtc_mh_factor -gt 0) {
        $CoinName = Get-CoinName $APICurrenciesResponse.$_.name
        $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
        if (-not $Algorithm_Norm) { $Algorithm_Norm = Get-Algorithm $Algorithm }

        $PoolHost = "mine.zergpool.com"
        $Port = $APICurrenciesResponse.$_.port
        $MiningCurrency = $APICurrenciesResponse.$_.symbol | Select-Object -Index 0
        $Workers = $APICurrenciesResponse.$_.workers
        $Fee = $APIStatusResponse.$Algorithm.Fees / 100

        $Divisor = 1000000000 <#check#> * [Double]$APIStatusResponse.$Algorithm.mbtc_mh_factor

        $Stat = Set-Stat -Name "$($PoolFileName)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
        $Stat = Set-Stat -Name "$($PoolFileName)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

        try {
            $EstimateCorrection = ($APIStatusResponse.$Algorithm.actual_last24h / 1000) / $APIStatusResponse.$Algorithm.estimate_last24h
        }
        catch { }

        $PoolRegions | ForEach-Object {
            $Region = $_
            $Region_Norm = Get-Region $Region

            if ($Wallets.$MiningCurrency) {
                #Option 3
                [PSCustomObject]@{
                    Name               = "$PoolFileName-Coin"
                    Algorithm          = $Algorithm_Norm
                    CoinName           = $CoinName
                    Price              = $Stat.Live
                    StablePrice        = $Stat.Week
                    MarginOfError      = $Stat.Week_Fluctuation
                    Protocol           = "stratum+tcp"
                    Host               = "$($Algorithm).$($PoolHost)"
                    Port               = $Port
                    User               = $Wallets.$_
                    Pass               = "ID=$Worker,c=$_,mc=$MiningCurrency$($PasswordSuffix.Algorithm."*")$($PasswordSuffix.Algorithm.$Algorithm_Norm)$($PasswordSuffix.CoinName."*")$($PasswordSuffix.CoinName.$CoinName)"
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
                        Name               = "$PoolFileName-Coin"
                        Algorithm          = $Algorithm_Norm
                        CoinName           = $CoinName
                        Price              = $Stat.Live
                        StablePrice        = $Stat.Week
                        MarginOfError      = $Stat.Week_Fluctuation
                        Protocol           = "stratum+tcp"
                        Host               = "$Algorithm.$PoolHost"
                        Port               = $Port
                        User               = $Wallets.$_
                        Pass               = "ID=$Worker,c=$_,mc=$MiningCurrency$($PasswordSuffix.Algorithm."*")$($PasswordSuffix.Algorithm.$Algorithm_Norm)$($PasswordSuffix.CoinName."*")$($PasswordSuffix.CoinName.$CoinName)"
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
