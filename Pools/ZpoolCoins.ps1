using module ..\Include.psm1

# Static values per pool, if set will override values from start.bat
#$Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF"
$Wallet = "187r43tmnLXqwJzqz99jrCeMJmRgfKa9B8"
#$WorkerName = "Blackbox"
#$Password = "x"
#$PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
#$MinPoolWorkers = 10 * $BenchmarkMode# Minimum workers required to mine on coin, if less skip the coin
$ProfitLessFee = $true
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
# $DisabledAlgorithms = @("ethash","X17")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
$Fee = 3 #Default pool fee in %

$ShortPoolName = "ZP" # Short pool name
#End of user settable variables

$ZpoolCoins_Regions = "US"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URL = "http://www.zpool.ca/api/currencies"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to.";return}

if (-not $PriceTimeSpan) {
    $PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

# Cannot do SSL
if ($SSL) {Write-Log -Level Warn "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool.";return}

$ZpoolCoins_Request = [PSCustomObject]@{}
try {
    $ZpoolCoins_Request = Invoke-RestMethod $URL -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select -ExpandProperty Name | Where {$ZpoolCoins_Request.$_.algo} | ForEach {
    
    $ZpoolCoins_Algorithm = $ZpoolCoins_Request.$_.algo

    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $ZpoolCoins_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $ZpoolCoins_Algorithm) -and $ZpoolCoins_Request.$_.workers -ge ($MinPoolWorkers * $BenchmarkMode) -and [Double]$ZpoolCoins_Request.$_.estimate -gt 0) {
        
        $ZpoolCoins_Host = "mine.zpool.ca"
        $ZpoolCoins_Port = $ZpoolCoins_Request.$_.port
        $ZpoolCoins_Algorithm_Norm = Get-Algorithm $ZpoolCoins_Algorithm
        
        if ($Fee) {$ZpoolCoins_Fee = [Double]$Fee} else {$ZpoolCoins_Fee = 0}
        if ($ProfitLessFee) {$ZpoolCoins_ProfitFactor = [Double]($ProfitFactor * (100 - $ZpoolCoins_Fee) / 100)} else {$ZpoolCoins_ProfitFactor = [Double]$ProfitFactor}
        
        $ZpoolCoins_Coin = (Get-Culture).TextInfo.ToTitleCase(($ZpoolCoins_Request.$_.name -replace "-", " " -replace "_", " ")) -replace " "
        $ZpoolCoins_Info  = "ProfitFactor: $($ZpoolCoins_ProfitFactor.ToString("N3")) (Fee: $($ZpoolCoins_Fee.ToString("N1"))%) [Workers: $($ZpoolCoins_Request.$_.workers) / Shares: $($ZpoolCoins_Request.$_.shares)] | Coin: $ZpoolCoins_Coin"

        $Divisor = 1000000000 / $ZpoolCoins_ProfitFactor

        switch ($ZpoolCoins_Algorithm)
        {
            "equihash"  {$Divisor /= 1000}
            "blake2s"   {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "decred"    {$Divisor *= 1000}
			"keccak"    {$Divisor *= 1000}
            "quark"     {$Divisor *= 1000000}
            "Qubit"     {$Divisor *= 1000}
            "X11"       {$Divisor *= 1000000}
            "X13"       {$Divisor *= 1000}
            "scrypt"    {$Divisor *= 1000}
        }

        if ((Get-Stat -Name "$($Name)_$($ZpoolCoins_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($ZpoolCoins_Algorithm_Norm)_Profit" -Value ([Double]$ZpoolCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true}
        else {$Stat = Set-Stat -Name "$($Name)_$($ZpoolCoins_Algorithm_Norm)_Profit" -Value ($ZpoolCoins_Request.$_.estimate / $Divisor) -Duration (New-TimeSpan -Days 1)}

        $ZpoolCoins_Regions | ForEach-Object {
            $ZpoolCoins_Region = $_
            $ZpoolCoins_Region_Norm = Get-Region $ZpoolCoins_Region
        
            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $ZpoolCoins_Algorithm
                Info            = $ZpoolCoins_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.$($PriceTimeSpan)
                MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                Protocol        = "stratum+tcp"
                Host            = $ZpoolCoins_Host
                Hosts           = $ZpoolCoins_Host
                Port            = $ZpoolCoins_Port
                User            = $Wallet
                Pass            = "$WorkerName,c=$PayoutCurrency"
                Region          = $ZpoolCoins_Region 
                SSL             = $SSL
                Updated         = $Stat.Updated
            }
        }
    }
}
Sleep 0