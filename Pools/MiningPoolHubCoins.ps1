using module ..\Include.psm1

# Static values per pool, if set will override values from Config.ps1
# $UserName = "UselessGuru"
# $WorkerName = "Blackbox"
# $Password = "x"
# $PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
# $MinPoolWorkers = 10 * $BenchmarkMode# Minimum workers required to mine on coin, if less skip the coin
# $ProfitLessFee = $true# If $true reported profit will be less fees as sent by the pool
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
#$DisabledAlgorithms = @("lyra2z","cryptonight") # 'stratum connection interupted'

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
$Fee = 1 # Default pool fee in %

$ShortPoolName = "MPHC" # Short pool name
#End of user settable variables

$MiningPoolHubCoins_Regions = "Europe", "US", "Asia" #Valid values "Europe", "US", "Asia"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URL = "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"

if (-not $UserName) {Write-Log -Level Warn "Pool API ($Name) has no miner username to mine to.";return}

if (-not $PriceTimeSpan) {
    $PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

$MiningPoolHubCoins_Request = [PSCustomObject]@{}

try {
    $MiningPoolHubCoins_Request = Invoke-RestMethod $URL -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($MiningPoolHubCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$MiningPoolHubCoins_Request.return | Where {$_.algo} | Where-Object {$_.pool_hash -gt 0} | ForEach-Object {
    
    $MiningPoolHubCoins_Algorithm = $_.algo

    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $MiningPoolHubCoins_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $MiningPoolHubCoins_Algorithm) -and [Double]$_.profit -gt 0) {
    
        $MiningPoolHubCoins_Hosts = $_.host_list.split(";")
        $MiningPoolHubCoins_Port = $_.port
        $MiningPoolHubCoins_Algorithm_Norm = Get-Algorithm $MiningPoolHubCoins_Algorithm
        if ($MiningPoolHubCoins_Algorithm_Norm -eq "Sia") {$MiningPoolHubCoins_Algorithm_Norm = "SiaClaymore"} #temp fix

        if ($Fee) {$MiningPoolHubCoins_Fee = [Double]$Fee} else {$MiningPoolHubCoins_Fee = 0}
        if ($ProfitLessFee) {$MiningPoolHubCoins_ProfitFactor = [Double]($ProfitFactor * (100 - $MiningPoolHubCoins_Fee) / 100)} else {$MiningPoolHubCoins_ProfitFactor = [Double]$ProfitFactor}

        $MiningPoolHubCoins_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.coin_name -replace "-", " " -replace "_", " ")) -replace " "
        $MiningPoolHubCoins_Info = "ProfitFactor: $($MiningPoolHubCoins_ProfitFactor.ToString("N3")) (Fee: $($MiningPoolHubCoins_Fee.ToString("N1"))%) [Reward: $($_.reward) / Difficulty: $($_.difficulty)] | Coin: $MiningPoolHubCoins_Coin"

        $Divisor = 1000000000 / $MiningPoolHubCoins_ProfitFactor
        
        $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHubCoins_Coin)_Profit" -Value ($_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true
        
        $MiningPoolHubCoins_Regions | ForEach-Object {
            $MiningPoolHubCoins_Region = $_
            $MiningPoolHubCoins_Region_Norm = Get-Region $MiningPoolHubCoins_Region

            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $MiningPoolHubCoins_Algorithm_Norm
                Info            = $MiningPoolHubCoins_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.$($PriceTimeSpan)
                MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                Protocol        = "stratum+tcp"
                Host            = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                Hosts           = $MiningPoolHubCoins_Hosts -join ";"
                Port            = $MiningPoolHubCoins_Port
                User            = "$UserName.$WorkerName"
                Pass            = "$Password"
                Region          = $MiningPoolHubCoins_Region_Norm
                SSL             = $false
                Updated         = $Stat.Updated
            }

            if ($MiningPoolHubCoins_Algorithm_Norm -eq "Cryptonight" -or $MiningPoolHubCoins_Algorithm_Norm -eq "Equihash") {
                [PSCustomObject]@{
                    PoolName      = $PoolName
                    Algorithm     = $MiningPoolHubCoins_Algorithm_Norm
                    Info          = $MiningPoolHubCoins_Info
                    Price         = $Stat.Live
                    StablePrice   = $Stat.$($PriceTimeSpan)
                    MarginOfError = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                    Protocol      = "stratum+ssl"
                    Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                    Hosts         = $MiningPoolHubCoins_Hosts -join ";"
                    Port          = $MiningPoolHubCoins_Port
                    User          = "$UserName.$WorkerName"
                    Pass          = "$Password"
                    Region        = $MiningPoolHubCoins_Region_Norm
                    SSL           = $true
                    Updated       = $Stat.Updated
                }
            }

            if ($MiningPoolHubCoins_Algorithm_Norm -eq "Ethash" -and $MiningPoolHubCoins_Coin -NotLike "*ethereum*") {
                [PSCustomObject]@{
                    Name          = $PoolName
                    Algorithm     = "$($MiningPoolHubCoins_Algorithm_Norm)2gb"
                    Info          = $MiningPoolHubCoins_Info
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                    Hosts         = $MiningPoolHubCoins_Hosts -join ";"
                    Port          = $MiningPoolHubCoins_Port
                    User          = "$UserName.$WorkerName"
                    Pass          = "$Password"
                    Region        = $MiningPoolHubCoins_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                }

                if ($MiningPoolHubCoins_Algorithm_Norm -eq "Cryptonight" -or $MiningPoolHubCoins_Algorithm_Norm -eq "Equihash") {
                    [PSCustomObject]@{
                        Name          = $PoolName
                        Algorithm     = "$($MiningPoolHubCoins_Algorithm_Norm)2gb"
                        Info          = $MiningPoolHubCoins_Info
                        Price         = $Stat.Live
                        StablePrice   = $Stat.$($PriceTimeSpan)
                        MarginOfError = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                        Protocol      = "stratum+ssl"
                        Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                        Hosts         = $MiningPoolHubCoins_Hosts -join ";"
                        Port          = $MiningPoolHubCoins_Port
                        User          = "$UserName.$WorkerName"
                        Pass          = "$Password"
                        Region        = $MiningPoolHubCoins_Region_Norm
                        SSL           = $true
                        Updated       = $Stat.Updated
                    }
                }
            }
        }
    }
}
Sleep 0