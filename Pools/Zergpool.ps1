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

$ShortPoolName = "ZergP" # Short pool name
#End of user settable variables

$Zergpool_Regions = "US"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URI = "http://api.zergpool.com:8080/api/status"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to."; return}

# Cannot do SSL
if ($SSL) {Write-Log -Level Warn "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool.";return}

$Zergpool_Request = [PSCustomObject]@{}
try {
    $Zergpool_Request = Invoke-RestMethod $URI -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($Zergpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$Zergpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select -ExpandProperty Name | Where-Object {$Zergpool_Request.$_.hashrate -gt 0} | ForEach-Object {
    
    $Zergpool_Algorithm = $_
    
    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $Zergpool_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $Zergpool_Algorithm) -and $Zergpool_Request.$_.workers -ge ($MinPoolWorkers * -not $BenchmarkMode)) {
    
        $Zergpool_Host = "zergpool.com"
        $Zergpool_Port = $Zergpool_Request.$_.port
        $Zergpool_Algorithm_Norm = Get-Algorithm $Zergpool_Algorithm
        
        if ($Fee) {$Zergpool_Fee = [Int]$Fee} else {$Zergpool_Fee = $Zergpool_Request.$_.fees}
        if ($ProfitLessFee) {$Zergpool_ProfitFactor = [Double]($ProfitFactor * (100 - $Zergpool_Fee) / 100)} else {$Zergpool_ProfitFactor = [Double]$ProfitFactor}
                
        $Zergpool_Info = "ProfitFactor: $($Zergpool_ProfitFactor.ToString("N3")) (Fee: $($Zergpool_Fee.ToString("N1"))%) [Workers: $($Zergpool_Request.$_.workers) / Coins: $($Zergpool_Request.$_.Coins)]"

        $Divisor = 1000000 / $Zergpool_ProfitFactor
    	
        switch ($Zergpool_Algorithm_Norm) {
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
        
        if ((Get-Stat -Name "$($Name)_$($Zergpool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Zergpool_Algorithm_Norm)_Profit" -Value ([Double]$Zergpool_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
        else {$Stat = Set-Stat -Name "$($Name)_$($Zergpool_Algorithm_Norm)_Profit" -Value ($Zergpool_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

        $Zergpool_Regions | ForEach-Object {
            $Zergpool_Region = $_
            $Zergpool_Region_Norm = Get-Region $Zergpool_Region
        
            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $Zergpool_Algorithm_Norm
                Info            = $Zergpool_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.Week
                MarginOfError   = $Stat.Week_Fluctuation
                Protocol        = "stratum+tcp"
                Host            = "$Zergpool_Host"
                Hosts           = "$Zergpool_Host"
                Port            = $Zergpool_Port
                User            = $Wallet
                Pass            = " c=$PayoutCurrency"
                Region          = $Zergpool_Region_Norm
                SSL             = $SSL
                Updated         = $Stat.Updated
            }
        }
    }
}