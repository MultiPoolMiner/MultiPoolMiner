using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$BlockMasters_Request = [PSCustomObject]@{}

try {
    $BlockMasters_Request = Invoke-RestMethod "http://www.blockmasters.co/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $BlockMastersCoins_Request = Invoke-RestMethod "http://www.blockmasters.co/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if ((($BlockMasters_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) -or (($BlockMastersCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1)) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$BlockMasters_Regions = "us"

#Pool allows payout in BTC, DOGE, LTC & any currency available in API. Define desired payout currency in $Config.$Pool.<Currency>
$BlockMasters_Currencies = @("BTC", "DOGE", "LTC") + ($BlockMastersCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$BlockMasters_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$DisabledAlgorithms -inotcontains (Get-Algorithm $BlockMasters_Request.$_.name) -and $BlockMasters_Request.$_.hashrate -gt 0} | ForEach-Object {
    $BlockMasters_Host = "blockmasters.co"
    $BlockMasters_Port = $BlockMasters_Request.$_.port
    $BlockMasters_Algorithm = $BlockMasters_Request.$_.name
    $BlockMasters_Algorithm_Norm = Get-Algorithm $BlockMasters_Algorithm
    $BlockMasters_Coin = ""

    $Divisor = 1000000

    switch ($BlockMasters_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit" -Value ([Double]$BlockMasters_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit" -Value ([Double]$BlockMasters_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $BlockMasters_Regions | ForEach-Object {
        $BlockMasters_Region = $_
        $BlockMasters_Region_Norm = Get-Region $BlockMasters_Region

        $BlockMasters_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $BlockMasters_Algorithm_Norm
                Info          = $BlockMasters_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $BlockMasters_Host
                Port          = $BlockMasters_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $BlockMasters_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}