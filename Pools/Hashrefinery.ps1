using module ..\Include.psm1

# Static values per pool, if set will override values from start.bat
#$Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF"
#$WorkerName = "Blackbox"
#$PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
#$MinPoolWorkers = 10 * $BenchmarkMode# Minimum workers required to mine on coin, if less skip the coin
$ProfitLessFee = $true
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
# $DisabledAlgorithms = @("skein","X17")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
#$Fee = 0 # Default fee for all algos in %; if uncommented fee information from pool/algo is used

$ShortPoolName = "HRef" # Short pool name
#End of user settable variables

$HashRefinery_Regions = "us"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URL = "http://pool.hashrefinery.com/api/status"

if (-not $Wallet) {Write-Warning "Pool API ($Name) has no wallet address to mine to.";return}

if (-not $PriceTimeSpan) {
    $PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

# Cannot do SSL
if ($SSL) {
    Write-Warning "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool."
    return
}

$HashRefinery_Request = [PSCustomObject]@{}
try {
    $HashRefinery_Request = Invoke-RestMethod $URL -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed."
	return
}

if (($HashRefinery_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing."
    return
}

$HashRefinery_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $HashRefinery_Algorithm = $_

    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $HashRefinery_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $HashRefinery_Algorithm) -and $HashRefinery_Request.$_.workers -ge ($MinPoolWorkers * -not $BenchmarkMode)) {
        
        $HashRefinery_Host = "hashrefinery.com"
        $HashRefinery_Port = $HashRefinery_Request.$_.port
        $HashRefinery_Algorithm_Norm = Get-Algorithm $HashRefinery_Algorithm
        
        if ($Fee) {$HashRefinery_Fee = [Double]$Fee} else {$HashRefinery_Fee = (100 - $HashRefinery_Request.$_.fees) / 100}
        if ($ProfitLessFee) {$HashRefinery_ProfitFactor = [Double]($ProfitFactor * $HashRefinery_Fee)} else {$HashRefinery_ProfitFactor = [Double]$ProfitFactor}
        
        $HashRefinery_Info = "ProfitFactor: $($HashRefinery_ProfitFactor.ToString("N3")) (Fee: $($HashRefinery_Fee.ToString("N1"))%) [Workers: $($HashRefinery_Request.$_.workers) / Coins: $($HashRefinery_Request.$_.Coins)]"
        
        $Divisor = 1000000 / $HashRefinery_ProfitFactor

        switch ($HashRefinery_Algorithm_Norm) {
            "equihash"  {$Divisor /= 1000}
            "blake2s"   {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "decred"    {$Divisor *= 1000}
        }

        if ((Get-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
        else {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

        $HashRefinery_Regions | ForEach-Object {
            $HashRefinery_Region = $_
            $HashRefinery_Region_Norm = Get-Region $HashRefinery_Region

            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $HashRefinery_Algorithm_Norm
                Info            = $HashRefinery_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.$($PriceTimeSpan)
                MarginOfError   = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                Protocol        = "stratum+tcp"
                Host            = "$HashRefinery_Algorithm.$HashRefinery_Region.$HashRefinery_Host"
                Hosts           = ($HashRefinery_Regions | ForEach {$HashRefinery_Algorithm + "." + $_ + "." + $HashRefinery_Host})
                Port            = $HashRefinery_Port
                User            = $Wallet
                Pass            = "$WorkerName,c=$PayoutCurrency"
                Region          = $HashRefinery_Region_Norm
                SSL             = $false
                Updated         = $Stat.Updated
            }
        }
    }
}
Sleep 0