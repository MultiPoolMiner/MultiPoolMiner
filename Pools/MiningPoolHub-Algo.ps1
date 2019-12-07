using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan, #to be removed
    [string]$User, 
    [String]$Worker, #under review
    [Double]$EstimateCorrection, #to be removed
    [Double]$PricePenaltyFactor #to be removed
)

$PoolName = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $User) { 
    Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no username specified. "
    return
}

$PoolAPIUri = "http://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")"
$PoolRegions = "europe", "us-east", "asia"
$RetryCount = 3
$RetryDelay = 2

while (-not ($APIResponse.return) -and $RetryCount -gt 0) { 
    try { 
        if (-not $APIResponse.return) { $APIResponse = Invoke-RestMethod $PoolAPIUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop }
    }
    catch { }
    if (-not $APIResponse.return) { 
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--
    }
}

if (-not $APIResponse) { 
    Write-Log -Level Warn "Pool API ($PoolName) has failed. "
    return
}

if ($APIResponse.return.count -le 1) { 
    Write-Log -Level Warn "Pool API ($PoolName) returned nothing. "
    return
}

Write-Log -Level Verbose "Processing pool data ($PoolName). "
$APIResponse.return | Where-Object { $_.profit -gt 0 } | ForEach-Object { 
    $PoolEntry = $_
    $PoolHosts = [String[]]($PoolEntry.all_host_list.split(";"))
    $CoinName = Get-CoinName $PoolEntry.current_mining_coin
    $CurrencySymbol = [String]$PoolEntry.current_mining_coin_symbol
    $Algorithm_Norm = Get-Algorithm $PoolEntry.algo
    if ($Algorithm_Norm -eq "Sia") { $Algorithm_Norm = "Sia-Claymore" }

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($PoolName)_$($Algorithm_Norm)_Profit" -Value ($_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

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
            Host               = [String]($PoolHosts | Sort-Object -Descending { $_ -ilike "$Region*" } | Select-Object -First 1)
            Port               = [Int]$PoolEntry.algo_switch_port
            User               = "$User.$Worker"
            Pass               = "x"
            Region             = $Region_Norm
            SSL                = $false
            Updated            = $Stat.Updated
            Fee                = [Decimal](0.9 / 100)
            EstimateCorrection = [Decimal]1
        }
        [PSCustomObject]@{ 
            Algorithm          = $Algorithm_Norm
            CoinName           = $CoinName
            CurrencySymbol     = $CurrencySymbol
            Price              = $Stat.Live
            StablePrice        = $Stat.Week
            MarginOfError      = $Stat.Week_Fluctuation
            Protocol           = "stratum+ssl"
            Host               = [String]($PoolHosts | Sort-Object -Descending { $_ -ilike "$Region*" } | Select-Object -First 1)
            Port               = [Int]$PoolEntry.algo_switch_port
            User               = "$User.$Worker"
            Pass               = "x"
            Region             = $Region_Norm
            SSL                = $true
            Updated            = $Stat.Updated
            Fee                = [Decimal](0.9 / 100)
            EstimateCorrection = [Decimal]1
        }
    }
}
