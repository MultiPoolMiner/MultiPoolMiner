using module ..\Include.psm1

# Static values per pool, if set will override values from Config.ps1
# $Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF"
# $WorkerName = "Blackbox"
# $PayoutCurrency = "BTC" # mining earnings will be autoconverted and paid out in this currency
# $MinPoolWorkers = 10 * $BenchmarkMode# Minimum workers required to mine on coin, if less skip the coin
# $ProfitLessFee = $true# If $true reported profit will be less fees as sent by the pool
# End static values per pool, if set will override values from start.bat

# In case some algos are not working properly, comma separated list
# $DisabledAlgorithms = @("skein","X17")

$ProfitFactor = 1 # 1 = 100%, use lower number to compensate for overoptimistic profit estimates sent by pool
#$Fee = 0 # Default fee for all algos in %; if uncommented fee information from pool/algo is used

$ShortPoolName = "IYMP" # Short pool name
#End of user settable variables

$HashRefinery_Regions = "us"
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
if ($UseShortPoolNames -and $ShortPoolName) {$PoolName = $ShortPoolName} else {$PoolName = $Name}
$URI = "http://www.italyiimp.com/api/status"

if (-not $Wallet) {Write-Log -Level Warn "Pool API ($Name) has no wallet address to mine to.";return}

if (-not $PriceTimeSpan) {
    $PriceTimeSpan = "Week" # Week, Day, Hour, Minute_10, Minute_5
}

$ItalYiiMP_Request = [PSCustomObject]@{}

try {
    $ItalYiiMP_Request = Invoke-RestMethod $URI -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
    return
}

if (($ItalYiiMP_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing. "
    return
}


$ItalYiiMP_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$ItalYiiMP_Request.$_.hashrate -gt 0} | ForEach-Object {
    $ItalYiiMP_Host = "mine.italyiimp.com"
    $ItalYiiMP_Port = $ItalYiiMP_Request.$_.port
    $ItalYiiMP_Algorithm = $ItalYiiMP_Request.$_.name
    $ItalYiiMP_Algorithm_Norm = Get-Algorithm $ItalYiiMP_Algorithm
    $ItalYiiMP_Coin = ""

    $Divisor = 1000000

    switch ($ItalYiiMP_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "keccak" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($ItalYiiMP_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($ItalYiiMP_Algorithm_Norm)_Profit" -Value ([Double]$ItalYiiMP_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    else {$Stat = Set-Stat -Name "$($Name)_$($ItalYiiMP_Algorithm_Norm)_Profit" -Value ([Double]$ItalYiiMP_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

    $ItalYiiMP_Regions | ForEach-Object {
        $ItalYiiMP_Region = $_
        $ItalYiiMP_Region_Norm = Get-Region $ItalYiiMP_Region

        if ($Wallet) {
            [PSCustomObject]@{
                Algorithm     = $ItalYiiMP_Algorithm_Norm
                Info          = $ItalYiiMP_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.$($PriceTimeSpan)
                MarginOfError = $Stat.$("$($PriceTimeSpan)_Fluctuation")
                Protocol      = "stratum+tcp"
                Host          = "$ItalYiiMP_Algorithm.$ItalYiiMP_Host"
                Port          = $ItalYiiMP_Port
                User          = $Wallet
                Pass          = "$WorkerName,c=BTC"
                Region        = $ItalYiiMP_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
