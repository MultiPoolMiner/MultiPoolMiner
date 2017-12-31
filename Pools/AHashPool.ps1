using module ..\Include.psm1

# Static values per pool, if set will override values from start.bat
#$Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF"
#$WorkerName = "Blackbox"
#$PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
#$MinPoolWorkers = 10 * $BenchmarkMode# Minimum workers required to mine on coin, if less skip the coin
$ProfitLessFee = $true
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
#$DisabledAlgorithms = @("neoscrypt")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
#$Fee = 0 # Default fee for all algos in %; if uncommented fee information from pool/algo is used
$ShortPoolName = "AHP" # Short pool name
#End of user settable variables

$AHashPool_Regions = "us"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URL = "http://www.AHashPool.com/api/status"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to.";return}

if (-not $PriceTimeSpan) {
	$PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

# Cannot do SSL
if ($SSL) {
	Write-Log -Level Warn "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool."
	return
}

$AHashPool_Request = [PSCustomObject]@{}
try {
	$AHashPool_Request = Invoke-RestMethod $URL -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 10 -ErrorAction Stop
}
catch {
	Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($AHashPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$AHashPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

	$AHashPool_Algorithm = $_

	# Do only for selected algorithms
	if ($DisabledAlgorithms -inotcontains $AHashPool_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $AHashPool_Algorithm) -and $AHashPool_Request.$_.workers -ge ($MinPoolWorkers * -not $BenchmarkMode)) {

		$AHashPool_Host = "mine.AHashPool.com"
		$AHashPool_Port = $AHashPool_Request.$_.port
		$AHashPool_Algorithm_Norm = Get-Algorithm $AHashPool_Algorithm
        
        if ($Fee) {$AHashPool_Fee = [Double]$Fee} else {$AHashPool_Fee = $AHashPool_Request.$_.fees}
        if ($ProfitLessFee) {$AHashPool_ProfitFactor = $ProfitFactor * (100 - $AHashPool_Fee) / 100} else {$AHashPool_ProfitFactor = [Double]$ProfitFactor}
        
		$AHashPool_Info = "ProfitFactor: $($AHashPool_ProfitFactor.ToString("N3")) (Fee: $($AHashPool_Fee.ToString("N1"))%) [Workers: $($AHashPool_Request.$_.workers) / Coins: $($AHashPool_Request.$_.Coins)]"

		$Divisor = 1000000 / $AHashPool_ProfitFactor

		switch ($AHashPool_Algorithm_Norm) {
			"equihash"	{$Divisor /= 1000}
			"blake2s"	{$Divisor *= 1000}
			"blakecoin"	{$Divisor *= 1000}
			"decred"	{$Divisor *= 1000}
		}

		if ((Get-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit" -Value ([Double]$AHashPool_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
		else {$Stat = Set-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit" -Value ([Double]$AHashPool_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

		$AHashPool_Regions | ForEach-Object {
			$AHashPool_Region = $_
			$AHashPool_Region_Norm = Get-Region $AHashPool_Region

			[PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $AHashPool_Algorithm_Norm
				Info            = $AHashPool_Info
				Price           = $Stat.Live
				StablePrice     = $Stat.$($PriceTimeSpan)
				MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
				Protocol        = "stratum+tcp"
				Host            = "$AHashPool_Algorithm.$AHashPool_Host"
				Hosts           = "$AHashPool_Algorithm.$AHashPool_Host"
				Port            = $AHashPool_Port
				User            = $Wallet
				Pass            = "ID=$WorkerName,c=$PayoutCurrency"
				Region          = $AHashPool_Region_Norm
				SSL             = $false
				Updated         = $Stat.Updated
			}
		}
	}
}
Sleep 0