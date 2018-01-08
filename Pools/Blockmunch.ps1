using module ..\Include.psm1

# Static values per pool, if set will override values from Config.ps1
# $Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF"
# $WorkerName = "Blackbox"
# $PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
# $MinPoolWorkers = 10 * $BenchmarkMode# Minimum workers required to mine on coin, if less skip the coin
# $ProfitLessFee = $true# If $true reported profit will be less fees as sent by the pool
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
#$DisabledAlgorithms = @("neoscrypt")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
#$Fee = 0 # Default fee for all algos in %; if uncommented fee information from pool/algo is used

$ShortPoolName = "BM" # Short pool name
#End of user settable variables

$Blockmunch_Regions = "us"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URI = "http://www.Blockmunch.club/api/status"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to.";return}

if (-not $PriceTimeSpan) {
	$PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

# Cannot do SSL
if ($SSL) {
	Write-Log -Level Warn "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool."
	return
}

$Blockmunch_Request = [PSCustomObject]@{}
try {
	$Blockmunch_Request = Invoke-RestMethod $URI -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 10 -ErrorAction Stop
}
catch {
	Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($Blockmunch_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$Blockmunch_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Blockmunch_Request.$_.hashrate -gt 0} | ForEach-Object {

	$Blockmunch_Algorithm = $_

	# Do only for selected algorithms
	if ($DisabledAlgorithms -inotcontains $Blockmunch_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $Blockmunch_Algorithm) -and $Blockmunch_Request.$_.workers -ge ($MinPoolWorkers * -not $BenchmarkMode)) {

		$Blockmunch_Host = "Blockmunch.club"
		$Blockmunch_Port = $Blockmunch_Request.$_.port
		$Blockmunch_Algorithm_Norm = Get-Algorithm $Blockmunch_Algorithm
        
        if ($Fee) {$Blockmunch_Fee = [Double]$Fee} else {$Blockmunch_Fee = $Blockmunch_Request.$_.fees}
        if ($ProfitLessFee) {$Blockmunch_ProfitFactor = $ProfitFactor * (100 - $Blockmunch_Fee) / 100} else {$Blockmunch_ProfitFactor = [Double]$ProfitFactor}
        
		$Blockmunch_Info = "ProfitFactor: $($Blockmunch_ProfitFactor.ToString("N3")) (Fee: $($Blockmunch_Fee.ToString("N1"))%) [Workers: $($Blockmunch_Request.$_.workers) / Coins: $($Blockmunch_Request.$_.Coins)]"

		$Divisor = 1000000 / $Blockmunch_ProfitFactor

		switch ($Blockmunch_Algorithm_Norm) {
			"equihash"	{$Divisor /= 1000}
			"blake2s"	{$Divisor *= 1000}
			"blakecoin"	{$Divisor *= 1000}
			"decred"	{$Divisor *= 1000}
		}

		if ((Get-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit" -Value ([Double]$Blockmunch_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
		else {$Stat = Set-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit" -Value ([Double]$Blockmunch_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

		$Blockmunch_Regions | ForEach-Object {
			$Blockmunch_Region = $_
			$Blockmunch_Region_Norm = Get-Region $Blockmunch_Region

			[PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $Blockmunch_Algorithm_Norm
				Info            = $Blockmunch_Info
				Price           = $Stat.Live
				StablePrice     = $Stat.$($PriceTimeSpan)
				MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
				Protocol        = "stratum+tcp"
				Host            = $Blockmunch_Host
				Hosts           = $Blockmunch_Host
				Port            = $Blockmunch_Port
				User            = $Wallet
				Pass            = "ID=$WorkerName,c=$PayoutCurrency"
				Region          = $Blockmunch_Region_Norm
				SSL             = $false
				Updated         = $Stat.Updated
			}
		}
	}
}