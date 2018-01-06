using module ..\Include.psm1

# Static values per pool, if set will override values from Config.ps1
# $Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF"
# $WorkerName = "Blackbox"
# $PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
# $MinPoolWorkers = 5# Minimum workers required to mine on coin, if less skip the coin
# $ProfitLessFee = $true# If $true reported profit will be less fees as sent by the pool
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
#$DisabledAlgorithms = @("C11","blake2s")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
$Fee = 1 # Default pool fee

$ShortPoolName = "AHPC" # Short pool name
#End of user settable variables

$AHashPoolCoins_Regions = "us"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URL = "http://www.ahashpool.com/api/currencies"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to.";return}

if (-not $PriceTimeSpan) {
	$PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

# Cannot do SSL
if ($SSL) {
	Write-Log -Level Warn "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool."
	return
}

$AHashPoolCoins_Request = [PSCustomObject]@{}
try {
	$AHashPoolCoins_Request = Invoke-RestMethod $URL -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} -TimeoutSec 10 -ErrorAction Stop
}
catch {
	Write-Log -Level Warn "Pool API ($Name) has failed."
	return
}

if (($AHashPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
	Write-Log -Level Warn "Pool API ($Name) returned nothing."
	return
}

$AHashPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name |Where-Object {$AHashPoolCoins_Request.$_.hashrate -gt 0} |  ForEach-Object {

	$AHashPoolCoins_Algorithm = $AHashPoolCoins_Request.$_.algo

	# Do only for selected algorythms
	if ($DisabledAlgorithms -inotcontains $AHashPoolCoins_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $AHashPoolCoins_Algorithm) -and $AHashPoolCoins_Request.$_.workers -ge ($MinPoolWorkers * -not $BenchmarkMode) -and [Double]$AHashPoolCoins_Request.$_.estimate -gt 0) {

		$AHashPoolCoins_Host = "mine.ahashpool.com"
		$AHashPoolCoins_Port = $AHashPoolCoins_Request.$_.port
		$AHashPoolCoins_Algorithm_Norm = Get-Algorithm $AHashPoolCoins_Algorithm
        
        if ($Fee) {$AHashPoolCoins_Fee = [Double]$Fee} else {$AHashPoolCoins_Fee = 0}
        if ($ProfitLessFee) {$AHashPoolCoins_ProfitFactor = [Double]($ProfitFactor * (100 - $AHashPoolCoins_Fee) / 100)} else {$AHashPoolCoins_ProfitFactor = [Double]$ProfitFactor}

        $AHashPoolCoins_Coin = (Get-Culture).TextInfo.ToTitleCase(($AHashPoolCoins_Request.$_.name -replace "-", " " -replace "_", " ")) -replace " "
        $AHashPoolCoins_Info = "ProfitFactor: $($AHashPoolCoins_ProfitFactor.ToString("N3")) (Fee: $($AHashPoolCoins_Fee.ToString("N1"))%) [Workers: $($AHashPoolCoins_Request.$_.workers) / Shares: $($AHashPoolCoins_Request.$_.shares)] | Coin: $AHashPoolCoins_Coin"

		$Divisor = 1000000000 / $AHashPoolCoins_ProfitFactor

		switch ($AHashPoolCoins_Algorithm_Norm) {
			"equihash"	{$Divisor /= 1000}
			"blake2s"	{$Divisor *= 1000}
			"blakecoin"	{$Divisor *= 1000}
			"decred"	{$Divisor *= 1000}
		}

		$Stat = Set-Stat -Name "$($Name)_$($AHashPoolCoins_Algorithm_Norm)_Profit" -Value ($AHashPoolCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

		$AHashPoolCoins_Regions | ForEach-Object {
			$AHashPoolCoins_Region = $_
			$AHashPoolCoins_Region_Norm = Get-Region $AHashPoolCoins_Region

			[PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $AHashPoolCoins_Algorithm_Norm
				Info            = $AHashPoolCoins_Info
				Price           = $Stat.Live
				StablePrice     = $Stat.$($PriceTimeSpan)
				MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
				Protocol        = "stratum+tcp"
				Host            = "$AHashPoolCoins_Algorithm.$AHashPoolCoins_Host"
				Hosts           = "$AHashPoolCoins_Algorithm.$AHashPoolCoins_Host"
				Port            = $AHashPoolCoins_Port
				User            = $Wallet
				Pass            = "ID=$WorkerName,c=$PayoutCurrency"
				Region          = $AHashPoolCoins_Region_Norm
				SSL             = $SSL
				Updated         = $Stat.Updated
			}
		}
	}
}
Sleep 0