using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$BlockmunchCoins_Request = [PSCustomObject]@{}

try {
    $BlockmunchCoins_Request = Invoke-RestMethod "http://www.blockmunch.club/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BlockmunchCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$BlockmunchCoins_Regions = "us"

#Pool allows payout in BTC, DOGE, LTC & any currency available in API. Define desired payout currency in $Config.$Pool.<Currency>
$BlockmunchCoins_Currencies = @("BTC","DOGE","LTC") + ($BlockmunchCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

#Mine any coin defined in array $Config.$Pool.Coins[]
$BlockmunchCoins_MiningCurrencies = ($BlockmunchCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Where-Object {$Coins.count -eq 0 -or $Coins -icontains $BlockmunchCoins_Request.$_.name} | Select-Object -Unique
$BlockmunchCoins_MiningCurrencies | Where-Object {$DisabledCoins -inotcontains $BlockmunchCoins_Request.$_.name -and $DisabledAlgorithms -inotcontains (Get-Algorithm $BlockmunchCoins_Request.$_.algo) -and $BlockmunchCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $BlockmunchCoins_Host = "blockmunch.club"
    $BlockmunchCoins_Port = $BlockmunchCoins_Request.$_.port
    $BlockmunchCoins_Algorithm = $BlockmunchCoins_Request.$_.algo
    $BlockmunchCoins_Algorithm_Norm = Get-Algorithm $BlockmunchCoins_Algorithm
    $BlockmunchCoins_Coin = $BlockmunchCoins_Request.$_.name

    $Divisor = 1000000

    switch ($BlockmunchCoins_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($BlockmunchCoins_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($BlockmunchCoins_Algorithm_Norm)_Profit" -Value ([Double]$BlockmunchCoins_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($BlockmunchCoins_Algorithm_Norm)_Profit" -Value ([Double]$BlockmunchCoins_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $BlockmunchCoins_Regions | ForEach-Object {
        $BlockmunchCoins_Region = $_
        $BlockmunchCoins_Region_Norm = Get-Region $BlockmunchCoins_Region

        $BlockmunchCoins_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $BlockmunchCoins_Algorithm_Norm
                Info          = $BlockmunchCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $BlockmunchCoins_Host
                Port          = $BlockmunchCoins_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $BlockmunchCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}