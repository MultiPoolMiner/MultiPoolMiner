using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan, 
    [PSCustomObject]$Config #to be removed
)

$PoolName = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Wallets = $Config.Pools.$PoolName.Wallets #to be removed

# Guaranteed payout currencies
$Payout_Currencies = @("RVN") | Where-Object { $Wallets.$_ }
if (-not $Payout_Currencies) { 
    Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no wallet address specified. "
    return
}

$PoolRegions = "stratum" #Geo-balanced Stratum [recommended] (automatically connect to the best server based on your location, plus auto-failover)
$PoolAPIStatusUri = "https://ravenminer.com/api/status"
$RetryCount = 3
$RetryDelay = 2

while (-not ($APIStatusResponse) -and $RetryCount -gt 0) { 
    try { 
        $APIStatusResponse = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    }
    catch { }
    if (-not $APIStatusResponse) { 
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--
    }
}

if (-not $APIStatusResponse) { 
    Write-Log -Level Warn "Pool API ($PoolName) has failed. "
    return
}

if (($APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) { 
    Write-Log -Level Warn "Pool API ($PoolName) [StatusUri] returned nothing. "
    return
}

Write-Log -Level Verbose "Processing pool data ($PoolName). "
$APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $APIStatusResponse.$_.hashrate -gt 0 } | ForEach-Object { 
    $PoolHost = "ravenminer.com"
    $Port = [Int]$APIStatusResponse.$_.port
    $Algorithm_Norm = Get-Algorithm $APIStatusResponse.$_.name
    $Workers = [Int]$APIStatusResponse.$_.workers
    $Fee = [Decimal]($APIStatusResponse.$_.Fees / 100)

    $Divisor = 1000000000

    if ((Get-Stat -Name "$($PoolName)_$($Algorithm_Norm)_Profit") -eq $null) { $Stat = Set-Stat -Name "$($PoolName)_$($Algorithm_Norm)_Profit" -Value ($APIStatusResponse.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1) }
    else { $Stat = Set-Stat -Name "$($PoolName)_$($Algorithm_Norm)_Profit" -Value ($APIStatusResponse.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true }

    try { $EstimateCorrection = [Decimal](($APIStatusResponse.$_.actual_last24h / 1000) / $APIStatusResponse.$_.estimate_last24h) }
    catch { $EstimateCorrection = [Decimal]0 }

    $PoolRegions | ForEach-Object { 
        $Region = $_
        $Region_Norm = Get-Region $Region

        $Payout_Currencies | ForEach-Object { 
            [PSCustomObject]@{ 
                Algorithm          = $Algorithm_Norm
                CoinName           = "RavenCoin"
                CurrencySymbol     = "RVN"
                Price              = $Stat.Live
                StablePrice        = $Stat.Week
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+tcp"
                Host               = "$Region.$PoolHost"
                Port               = $Port
                User               = [String]$Wallets.$_
                Pass               = "ID=$($Config.Pools.$PoolName.Worker),c=$_"
                Region             = $Region_Norm
                SSL                = $false
                Updated            = $Stat.Updated
                Fee                = $Fee
                Workers            = $Workers
                EstimateCorrection = $EstimateCorrection
            }
            [PSCustomObject]@{ 
                Algorithm          = $Algorithm_Norm
                CoinName           = "RavenCoin"
                CurrencySymbol     = "RVN"
                Price              = $Stat.Live
                StablePrice        = $Stat.Week
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+ssl"
                Host               = "$Region.$PoolHost"
                Port               = [Int]("1$($Port)")
                User               = [String]$Wallets.$_
                Pass               = "ID=$($Config.Pools.$PoolName.Worker),c=$_"
                Region             = $Region_Norm
                SSL                = $true
                Updated            = $Stat.Updated
                Fee                = $Fee
                Workers            = $Workers
                EstimateCorrection = $EstimateCorrection
            }
        }
    }
}
