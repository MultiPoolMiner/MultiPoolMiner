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
# $DisabledAlgorithms = @("ethash")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
#$Fee = 0 # Default fee for all algos in %; if uncommented fee information from pool/algo is used

$ShortPoolName = "Blaze" # Short pool name
#End of user settable variables

$Blazepool_Regions = "US"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URI = "http://api.blazepool.com/status"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to."; return}

# Cannot do SSL
if ($SSL) {Write-Log -Level Warn "SSL option requested, but pool API ($Name) does not support SSL. Ignoring pool.";return}

$Blazepool_Request = [PSCustomObject]@{}
try {
    $Blazepool_Request = Invoke-RestMethod $URI -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed."
    return
}

if (($Blazepool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing."
    return
}

$Blazepool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select -ExpandProperty Name | Where-Object {$Blazepool_Request.$_.hashrate -gt 0} | ForEach-Object {

    $Blazepool_Algorithm = $_

    # Do only for selected algorithms
    if ($DisabledAlgorithms -inotcontains $Blazepool_Algorithm -and ($Algorithm -eq $null -or $Algorithm.count -eq 0 -or $Algorithm -icontains $Blazepool_Algorithm) -and $Blazepool_Request.$_.workers -ge ($MinPoolWorkers * -not $BenchmarkMode)) {

        $Blazepool_Host = "$Blazepool_Algorithm.mine.blazepool.com"
        $Blazepool_Port = $Blazepool_Request.$_.port
        $Blazepool_Algorithm_Norm = Get-Algorithm $Blazepool_Algorithm

        if ($Fee) {$Blazepool_Fee = [Int]$Fee} else {$Blazepool_Fee = $Blazepool_Request.$_.fees}
        if ($ProfitLessFee) {$Blazepool_ProfitFactor = [Double]($ProfitFactor * (100 - $Blazepool_Fee) / 100)} else {$Blazepool_ProfitFactor = [Double]$ProfitFactor}

        $Blazepool_Info = "ProfitFactor: $($Blazepool_ProfitFactor.ToString("N3")) (Fee: $($Blazepool_Fee.ToString("N1"))%) [Workers: $($Blazepool_Request.$_.workers) / Coins: $($Blazepool_Request.$_.Coins)]"

        $Divisor = 1000000 / $Blazepool_ProfitFactor

        switch ($Blazepool_Algorithm_Norm) {
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

        if ((Get-Stat -Name "$($Name)_$($Blazepool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Blazepool_Algorithm_Norm)_Profit" -Value ([Double]$Blazepool_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
        else {$Stat = Set-Stat -Name "$($Name)_$($Blazepool_Algorithm_Norm)_Profit" -Value ($Blazepool_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

        $Blazepool_Regions | ForEach-Object {
            $Blazepool_Region = $_
            $Blazepool_Region_Norm = Get-Region $Blazepool_Region

            [PSCustomObject]@{
                PoolName        = $PoolName
                Algorithm       = $Blazepool_Algorithm_Norm
                Info            = $Blazepool_Info
                Price           = $Stat.Live
                StablePrice     = $Stat.Week
                MarginOfError   = $Stat.Week_Fluctuation
                Protocol        = "stratum+tcp"
                Host            = "$Blazepool_Host"
                Hosts           = "$Blazepool_Host"
                Port            = $Blazepool_Port
                User            = $Wallet
                Pass            = " c=$PayoutCurrency"
                Region          = $Blazepool_Region_Norm
                SSL             = $SSL
                Updated         = $Stat.Updated
            }
        }
    }
}