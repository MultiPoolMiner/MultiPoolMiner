using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config #to be removed
)

$PoolName = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$PoolName.User) { 
    Write-Log -Level Verbose "Cannot mine on pool ($PoolName) - no username specified. "
    return
}

$PoolAPIUri = "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")"
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
$APIResponse.return | ForEach-Object { 
    $PoolEntry = $_
    $CoinName = Get-CoinName $PoolEntry.coin_name
    Switch ($CoinName) {
        "MaxCoin" { $PoolHosts = [String[]]($PoolEntry.host) } #temp Fix
        default   { $PoolHosts = [String[]]($PoolEntry.host_list.split(";")) }
    }
    $CurrencySymbol = [String]$PoolEntry.symbol
    $Algorithm_Norm = Get-AlgorithmFromCurrencySymbol $CurrencySymbol
    if (-not $Algorithm_Norm) { $Algorithm_Norm = Get-Algorithm $PoolEntry.algo }
    if ($Algorithm_Norm -eq "Sia") { $Algorithm_Norm = "SiaClaymore" } #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($PoolName)_$($CurrencySymbol)-$($Algorithm_Norm)_Profit" -Value ($_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

    if ($PoolHosts.Count -gt 1) { $Regions = $PoolRegions } else { $Regions = $Config.Region } #Do not create multiple pool objects if there is only one host

    $Regions | ForEach-Object { 
        $Region = $_
        $Region_Norm = Get-Region ($Region -replace "^us-east$", "us")

        [PSCustomObject]@{ 
            Algorithm      = $Algorithm_Norm
            CoinName       = $CoinName
            CurrencySymbol = $CurrencySymbol
            Price          = $Stat.Live
            StablePrice    = $Stat.Week
            MarginOfError  = $Stat.Week_Fluctuation
            Protocol       = "stratum+tcp"
            Host           = [String]($PoolHosts | Sort-Object -Descending { $_ -ilike "$Region*" } | Select-Object -First 1)
            Port           = [Int]$PoolEntry.port
            User           = "$($Config.Pools.$PoolName.User).$($Config.Pools.$PoolName.Worker)"
            Pass           = "x"
            Region         = $Region_Norm
            SSL            = $false
            Updated        = $Stat.Updated
            Fee            = [Decimal]($PoolEntry.fee / 100)
        }
        [PSCustomObject]@{ 
            Algorithm      = $Algorithm_Norm
            CoinName       = $CoinName
            CurrencySymbol = $CurrencySymbol
            Price          = $Stat.Live
            StablePrice    = $Stat.Week
            MarginOfError  = $Stat.Week_Fluctuation
            Protocol       = "stratum+ssl"
            Host           = [String]($PoolHosts | Sort-Object -Descending { $_ -ilike "$Region*" } | Select-Object -First 1)
            Port           = [Int]$PoolEntry.port
            User           = "$($Config.Pools.$PoolName.User).$($Config.Pools.$PoolName.Worker)"
            Pass           = "x"
            Region         = $Region_Norm
            SSL            = $true
            Updated        = $Stat.Updated
            Fee            = [Decimal]($PoolEntry.fee / 100)
        }
    }
}
