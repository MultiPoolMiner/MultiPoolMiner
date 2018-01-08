using module ..\Include.psm1

# Static values per pool, if set will override values from Config.ps1
# $Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF"
# $WorkerName = "Blackbox"
# $Password = "x"
# $PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
# $MinPoolWorkers = 10 * $BenchmarkMode# Minimum workers required to mine on coin, if less skip the coin
# $ProfitLessFee = $true# If $true reported profit will be less fees as sent by the pool
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
# $DisabledAlgorithms = @("ethash","X17")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
#$Fee = 0 # Default fee for all algos in %; if uncommented fee information from pool/algo is used

$ShortPoolName = "ZP" # Short pool name
#End of user settable variables

$Zpool_Regions = "US"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URI = "http://www.zpool.ca/api/status"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to."; return}

if (-not $PriceTimeSpan) {
    $PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

# Cannot do SSL
if ($SSL) {Write-Log -Level Warn "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool.";return}

$Zpool_Request = [PSCustomObject]@{}
try {
    $Zpool_Request = Invoke-RestMethod $URI -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select -ExpandProperty Name | Where-Object {$Zpool_Request.$_.hashrate -gt 0} | ForEach-Object {
    
    $Zpool_Algorithm = $_
    
    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $Zpool_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $Zpool_Algorithm) -and $Zpool_Request.$_.workers -ge ($MinPoolWorkers * -not $BenchmarkMode)) {
    
        $Zpool_Host = "mine.zpool.ca"
        $Zpool_Port = $Zpool_Request.$_.port
        $Zpool_Algorithm_Norm = Get-Algorithm $Zpool_Algorithm
        
        if ($Fee) {$Zpool_Fee = [Int]$Fee} else {$Zpool_Fee = $Zpool_Request.$_.fees}
        if ($ProfitLessFee) {$Zpool_ProfitFactor = [Double]($ProfitFactor * (100 - $Zpool_Fee) / 100)} else {$Zpool_ProfitFactor = [Double]$ProfitFactor}
                
        $Zpool_Info = "ProfitFactor: $($Zpool_ProfitFactor.ToString("N3")) (Fee: $($Zpool_Fee.ToString("N1"))%) [Workers: $($Zpool_Request.$_.workers) / Coins: $($Zpool_Request.$_.Coins)]"

        $Divisor = 1000000 / $Zpool_ProfitFactor
    	
        switch ($Zpool_Algorithm_Norm) {
            "equihash"  {$Divisor /= 1000}
            "blake2s"   {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "decred"    {$Divisor *= 1000}
			"keccak"    {$Divisor *= 1000}
            "x11"       {$Divisor *= 1000}
            "quark"     {$Divisor *= 1000}
            "qubit"     {$Divisor *= 1000}
            "scrypt"    {$Divisor *= 1000}
        }
        
        if ((Get-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
        else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ($Zpool_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

        $Zpool_Regions | ForEach-Object {
            $Zpool_Region = $_
            $Zpool_Region_Norm = Get-Region $Zpool_Region
        
            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $Zpool_Algorithm_Norm
                Info            = $Zpool_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.$($PriceTimeSpan)
                MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                Protocol        = "stratum+tcp"
                Host            = "$Zpool_Algorithm.$Zpool_Host"
                Hosts           = "$Zpool_Algorithm.$Zpool_Host"
                Port            = $Zpool_Port
                User            = $Wallet
                Pass            = "$WorkerName,c=$PayoutCurrency"
                Region          = $Zpool_Region_Norm
                SSL             = $SSL
                Updated         = $Stat.Updated
            }
        }
    }
}
Sleep 0