using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC", "DASH") | Where-Object {$Config.Pools.$Name.Wallets.$_}
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$PoolRegions = "europe"
$PoolAPIStatusUri = "http://api.zergpool.com:8080/api/status"
$PoolAPICurrenciesUri = "http://api.zergpool.com:8080/api/currencies"

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

$Payout_Currencies = (@($Payout_Currencies) + @($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object {$Config.Pools.$Name.Wallets.$_} | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesResponse.$_.hashrate -gt 0} | Foreach-Object {
 
    $Algorithm = $APICurrenciesResponse.$_.algo
    $CoinName = Get-CoinName $APICurrenciesResponse.$_.name

    $Divisor = 1000000000 * [Double]$APICurrenciesResponse.$_.mbtc_mh_factor
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
        $Port           = $APICurrenciesResponse.$_.port
        $MiningCurrency = $_ -split "-" | Select-Object -Index 0
        $Workers        = $APICurrenciesResponse.$_.workers
        $Fee            = if ($APIStatusResponse.$Algorithm) {$APIStatusResponse.$Algorithm.Fees / 100} else {5 / 100}

        $Stat = Set-Stat -Name "$($Name)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true
        $Stat = Set-Stat -Name "$($Name)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

        try {
            $EstimateCorrection = ($APIStatusResponse.$Algorithm.actual_last24h / 1000) / $APIStatusResponse.$Algorithm.estimate_last24h
        }
        catch {}

        $PoolRegions | ForEach-Object {
            $Region = $_
            $Region_Norm = Get-Region $Region

            if ($($Config.Pools.$Name.Wallets).$MiningCurrency) {
                #Option 3
                [PSCustomObject]@{
                    Algorithm          = $Algorithm_Norm
                    CoinName           = $CoinName
                    Price              = $Stat.Live
                    StablePrice        = $Stat.Week
                    MarginOfError      = $Stat.Week_Fluctuation
                    Protocol           = "stratum+tcp"
                    Host               = "$($Algorithm).$($PoolHost)"
                    Port               = $Port
                    User               = $Config.Pools.$Name.Wallets.$_
                    Pass               = "$($Config.Pools.$Name.Worker),c=$($_),mc=$MiningCurrency$($Config.Pools.$Name.PasswordSuffix.Algorithm."*")$($Config.Pools.$Name.PasswordSuffix.Algorithm.$Algorithm_Norm)$($Config.Pools.$Name.PasswordSuffix.CoinName."*")$($Config.Pools.$Name.PasswordSuffix.CoinName.$CoinName)"
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
                        Algorithm          = $Algorithm_Norm
                        CoinName           = $CoinName
                        Price              = $Stat.Live
                        StablePrice        = $Stat.Week
                        MarginOfError      = $Stat.Week_Fluctuation
                        Protocol           = "stratum+tcp"
                        Host               = "$Algorithm.$PoolHost"
                        Port               = $Port
                        User               = $Config.Pools.$Name.Wallets.$_
                        Pass               = "$($Config.Pools.$Name.Worker),c=$($_),mc=$MiningCurrency$($Config.Pools.$Name.PasswordSuffix.Algorithm."*")$($Config.Pools.$Name.PasswordSuffix.Algorithm.$Algorithm_Norm)$($Config.Pools.$Name.PasswordSuffix.CoinName."*")$($Config.Pools.$Name.PasswordSuffix.CoinName.$CoinName)"
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
