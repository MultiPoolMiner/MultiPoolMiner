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
$Fee = 1.1 # Default pool fee in %

$ShortPoolName = "MPH" # Short pool name
#End of user settable variables

$MiningPoolHub_Regions = "Europe", "US", "Asia" #Valid values "Europe", "US", "Asia"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URL = "http://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics"

if (-not $UserName) {Write-Log -Level Warn "Pool API ($Name) has no miner username to mine to.";return}

if (-not $PriceTimeSpan) {
    $PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

$MiningPoolHub_Request = [PSCustomObject]@{}
try {
    $MiningPoolHub_Request = Invoke-RestMethod $URL -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($MiningPoolHub_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$MiningPoolHub_Request.return | Where {$_.algo} | Where-Object {$MiningPoolHub_Request.$_.hashrate -gt 0} | ForEach-Object {

    $MiningPoolHub_Algorithm = $_.algo
    
    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $MiningPoolHub_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $MiningPoolHub_Algorithm)) {
            
        $MiningPoolHub_Hosts = $_.all_host_list.split(";")
        $MiningPoolHub_Port = $_.algo_switch_port
        $MiningPoolHub_Algorithm_Norm = Get-Algorithm $MiningPoolHub_Algorithm
        if ($Fee) {$MiningPoolHub_Fee = [Double]$Fee} else {$MiningPoolHub_Fee = 0}
        if ($ProfitLessFee) {$MiningPoolHub_ProfitFactor = [Double]($ProfitFactor * (100 - $MiningPoolHub_Fee) / 100)} else {$MiningPoolHub_ProfitFactor = [Double]$ProfitFactor}
    
        $MiningPoolHub_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.current_mining_coin -replace "-", " " -replace "_", " ")) -replace " "
        $MiningPoolHub_Info = "ProfitFactor: $($MiningPoolHub_ProfitFactor.ToString("N3")) (Fee: $($MiningPoolHub_Fee.ToString("N1"))%) | Coin: $MiningPoolHub_Coin"
        
        if ($MiningPoolHub_Algorithm_Norm -eq "Sia") {$MiningPoolHub_Algorithm_Norm = "SiaClaymore"} #temp fix

        $Divisor = 1000000000 / $MiningPoolHub_ProfitFactor 
        
        $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Algorithm_Norm)_Profit" -Value ($_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

        $MiningPoolHub_Regions | ForEach-Object {
            $MiningPoolHub_Region = $_
            $MiningPoolHub_Region_Norm = Get-Region $MiningPoolHub_Region

            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $MiningPoolHub_Algorithm_Norm
                Info            = $MiningPoolHub_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.$($PriceTimeSpan)
                MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                Protocol        = "stratum+tcp"
                Host            = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                Hosts           = $MiningPoolHub_Hosts -join ";"
                Port            = $MiningPoolHub_Port
                User            = "$UserName.$WorkerName"
                Pass            = "$Password"
                Region          = $MiningPoolHub_Region_Norm
                SSL             = $false
                Updated         = $Stat.Updated
            }
            
            if ($MiningPoolHub_Algorithm_Norm -eq "Cryptonight" -or $MiningPoolHub_Algorithm_Norm -eq "Equihash") {
                [PSCustomObject]@{
                    PoolName        = $PoolName
                    Algorithm       = $MiningPoolHub_Algorithm_Norm
                    Info            = $MiningPoolHub_Info
                    Price           = $Stat.Live
                    StablePrice     = $Stat.$($PriceTimeSpan)
                    MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                    Protocol        = "stratum+ssl"
                    Host            = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                    Hosts           = $MiningPoolHub_Hosts -join ";"
                    Port            = $MiningPoolHub_Port
                    User            = "$UserName.$WorkerName"
                    Pass            = "$Password"
                    Region          = $MiningPoolHub_Region_Norm
                    SSL             = $true
                    Updated         = $Stat.Updated
                }
            }
        }
    }
}
Sleep 0