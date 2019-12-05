using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan, 
    [PSCustomObject]$Config #to be removed
)

$PoolName = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Wallets = $Config.Pools.$PoolName.Wallets #to be removed

if (-not ($Wallets | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) -ne "BTC") { 
    Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no wallet address specified. "
    return
}

$PoolRegions = "asia", "eu", "us"
$PoolAPIStatusUri = "http://www.phi-phi-pool.com/api/status"
$PoolAPICurrenciesUri = "http://www.phi-phi-pool.com/api/currencies"
$RetryCount = 3
$RetryDelay = 2

while (-not ($APIStatusResponse -and $APICurrenciesResponse) -and $RetryCount -gt 0) { 
    try { 
        if (-not $APIStatusResponse) { $APIStatusResponse = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop }
        if (-not $APICurrenciesResponse) { $APICurrenciesResponse = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop }
    }
    catch { }
    if (-not ($APIStatusResponse -and $APICurrenciesResponse)) { 
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

#Pool does not do auto conversion to BTC
$Payout_Currencies = @($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Where-Object { $Wallets.$_ } | Sort-Object -Unique
if (-not $Payout_Currencies) { 
    Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no wallet address specified. "
    return
}

Write-Log -Level Verbose "Processing pool data ($PoolName). "
$APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $APICurrenciesResponse.$_.hashrate -gt 0 } | ForEach-Object { 

    # Not all algorithms are always exposed in API
    if ($APIStatusResponse.$($APICurrenciesResponse.$_.algo)) { 
        $APICurrenciesResponse.$_ | Add-Member Symbol $_ -ErrorAction SilentlyContinue

        $PoolHost = "phi-phi-pool.com"
        $Port = [Int]$APICurrenciesResponse.$_.port
        $CoinName = Get-CoinName $APICurrenciesResponse.$_.name
        $CurrencySymbol = [String]$APICurrenciesResponse.$_.symbol
        $Algorithm_Norm = Get-Algorithm $APICurrenciesResponse.$_.algo
        $Workers = [Int]$APICurrenciesResponse.$_.workers
        $Fee = [Decimal]($APIStatusResponse.$Algorithm.Fees / 100)

        $Divisor = 1000000000 * [Double]$APIStatusResponse.$($APICurrenciesResponse.$_.algo).mbtc_mh_factor

        $Stat = Set-Stat -Name "$($PoolName)_$($CurrencySymbol)_Profit" -Value ($APICurrenciesResponse.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

        try { $EstimateCorrection = [Decimal](($APIStatusResponse.$($APICurrenciesResponse.$_.algo).actual_last24h / 1000) / $APIStatusResponse.$($APICurrenciesResponse.$_.algo).estimate_last24h) }
        catch { $EstimateCorrection = [Decimal]1 }

        $PoolRegions | ForEach-Object { 
            $Region = $_
            $Region_Norm = Get-Region $Region

            [PSCustomObject]@{ 
                Algorithm          = $Algorithm_Norm
                CoinName           = $CoinName
                CurrencySymbol     = $CurrencySymbol
                Price              = $Stat.Live
                StablePrice        = $Stat.Week
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+tcp"
                Host               = "$Region.$PoolHost"
                Port               = $Port
                User               = "$Wallets.$CurrencySymbol"
                Pass               = "c=$CurrencySymbol"
                Region             = $Region_Norm
                SSL                = $false
                Updated            = $Stat.Updated
                Fee                = $Fee
                Workers            = $Workers
                EstimateCorrection = $EstimateCorrection
            }
        }
    }
}
