
using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$BlockMastersCoins_Request = [PSCustomObject]@{}

try {
    $BlockMastersCoins_Request = Invoke-RestMethod "http://www.BlockMasters.co/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BlockMastersCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$BlockMastersCoins_Regions = "us"

#Pool allows payout in BTC, DOGE, LTC & any currency available in API. Define desired payout currency in $Config.$Pool.<Currency>
$BlockMastersCoins_Currencies = @("BTC", "DOGE", "LTC") + ($BlockMastersCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

#Mine any coin defined in array $Config.$Pool.Coins[]
$BlockMastersCoins_MiningCurrencies = ($BlockMastersCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Where-Object {$Coin.count -eq 0 -or $Coin -icontains $BlockMastersCoins_Request.$_.name} | Select-Object -Unique
$BlockMastersCoins_MiningCurrencies | Where-Object {$ExcludeCoin -inotcontains $BlockMastersCoins_Request.$_.name -and $ExcludeAlgorithm -inotcontains (Get-Algorithm $BlockMastersCoins_Request.$_.algo) -and $BlockMastersCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $BlockMastersCoins_Host = "BlockMasters.co"
    $BlockMastersCoins_Port = $BlockMastersCoins_Request.$_.port
    $BlockMastersCoins_Algorithm = $BlockMastersCoins_Request.$_.algo
    $BlockMastersCoins_Algorithm_Norm = Get-Algorithm $BlockMastersCoins_Algorithm
    $BlockMastersCoins_Coin = $BlockMastersCoins_Request.$_.name
    $BlockMastersCoins_Currency = $_

    $Divisor = 1000000

    switch ($BlockMastersCoins_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($BlockMastersCoins_Currency)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($BlockMastersCoins_Currency)_Profit" -Value ([Double]$BlockMastersCoins_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($BlockMastersCoins_Currency)_Profit" -Value ([Double]$BlockMastersCoins_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $BlockMastersCoins_Regions | ForEach-Object {
        $BlockMastersCoins_Region = $_
        $BlockMastersCoins_Region_Norm = Get-Region $BlockMastersCoins_Region

        $BlockMastersCoins_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $BlockMastersCoins_Algorithm_Norm
                Info          = $BlockMastersCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $BlockMastersCoins_Host
                Port          = $BlockMastersCoins_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $BlockMastersCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}