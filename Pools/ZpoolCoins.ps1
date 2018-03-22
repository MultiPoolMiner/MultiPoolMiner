using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$ZpoolCoins_Request = [PSCustomObject]@{}

try {
    $ZpoolCoins_Request = Invoke-RestMethod "http://www.zpool.ca/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$ZpoolCoins_Regions = "us"

#Pool allows payout in BTC & any currency available in API. Define the desired payout currency in $Config.$Pool.<Currency>
$ZpoolCoins_Currencies = @("BTC") + ($ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

#Mine any coin defined in array $Config.$Pool.Coins[]
$ZpoolCoins_MiningCurrencies = ($ZpoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Where-Object {$Coins.count -eq 0 -or $Coins -icontains $ZpoolCoins_Request.$_.name} | Select-Object -Unique
#On Zpool all $ZpoolCoins_Request.$_.hashrate is 0, use workers instead
$ZpoolCoins_MiningCurrencies | Where-Object {$DisabledCoins -inotcontains $ZpoolCoins_Request.$_.name -and $DisabledAlgorithms -inotcontains (Get-Algorithm $ZpoolCoins_Request.$_.algo) -and $ZpoolCoins_Request.$_.workers -gt 0} | ForEach-Object {
    $ZpoolCoins_Host = "mine.zpool.ca"
    $ZpoolCoins_Port = $ZpoolCoins_Request.$_.port
    $ZpoolCoins_Algorithm = $ZpoolCoins_Request.$_.algo
    $ZpoolCoins_Algorithm_Norm = Get-Algorithm $ZpoolCoins_Algorithm
    $ZpoolCoins_Coin = $ZpoolCoins_Request.$_.name

    $Divisor = 1000000

    switch ($ZpoolCoins_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($ZpoolCoins_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($ZpoolCoins_Algorithm_Norm)_Profit" -Value ([Double]$ZpoolCoins_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($ZpoolCoins_Algorithm_Norm)_Profit" -Value ([Double]$ZpoolCoins_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $ZpoolCoins_Regions | ForEach-Object {
        $ZpoolCoins_Region = $_
        $ZpoolCoins_Region_Norm = Get-Region $ZpoolCoins_Region

        $ZpoolCoins_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $ZpoolCoins_Algorithm_Norm
                Info          = $ZpoolCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$ZpoolCoins_Algorithm.$ZpoolCoins_Host"
                Port          = $ZpoolCoins_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $ZpoolCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}