using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$ZergPoolCoins_Request = [PSCustomObject]@{}

try {
    $ZergPoolCoins_Request = Invoke-RestMethod "http://api.zergpool.com:8080/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$ZergPoolCoins_Regions = "us", "europe"

#Pool allows payout in BTC, LTC & any currency available in API. Define desired payout currency in $Config.$Pool.<Currency>
$ZergPoolCoins_Currencies = @("BTC", "LTC") + ($ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

#Mine any coin defined in array $Config.$Pool.Coins[]
$ZergPoolCoins_MiningCurrencies = ($ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Foreach-Object {if ($ZergPoolCoins_Request.$_.Symbol) {$ZergPoolCoins_Request.$_.Symbol} else {$_}} | Select-Object -Unique # filter ...-algo
$ZergPoolCoins_MiningCurrencies | Where-Object {$DisabledCoins -inotcontains $ZergPoolCoins_Request.$_.name -and $DisabledAlgorithms -inotcontains (Get-Algorithm $ZergPoolCoins_Request.$_.algo) -and ($Coins.count -eq 0 -or $Coins -icontains $ZergPoolCoins_Request.$_.name) -and $ZergPoolCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $ZergPoolCoins_Host = "mine.zergpool.com"
    $ZergPoolCoins_Port = $ZergPoolCoins_Request.$_.port
    $ZergPoolCoins_Algorithm = $ZergPoolCoins_Request.$_.algo
    $ZergPoolCoins_Algorithm_Norm = Get-Algorithm $ZergPoolCoins_Algorithm
    $ZergPoolCoins_Coin = $ZergPoolCoins_Request.$_.name
    $ZergPoolCoins_Currency = $_

    $Divisor = 1000000000

    switch ($ZergPoolCoins_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccak" {$Divisor *= 1000}
        "keccakc" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$ZergPoolCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $ZergPoolCoins_Regions | ForEach-Object {
        $ZergPoolCoins_Region = $_
        $ZergPoolCoins_Region_Norm = Get-Region $ZergPoolCoins_Region

        if (Get-Variable $ZergPoolCoins_Currency -ValueOnly -ErrorAction SilentlyContinue) {
            #Option 3
            [PSCustomObject]@{
                Algorithm     = $ZergPoolCoins_Algorithm_Norm
                Info          = $ZergPoolCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$ZergPoolCoins_Algorithm.$ZergPoolCoins_Host"
                Port          = $ZergPoolCoins_Port
                User          = Get-Variable $ZergPoolCoins_Currency -ValueOnly
                Pass          = "$Worker,c=$ZergPoolCoins_Currency,mc=$ZergPoolCoins_Currency"
                Region        = $ZergPoolCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
        elseif ($ZergPoolCoins_Request.$ZergPoolCoins_Currency.noautotrade -eq 0) {
            $ZergPoolCoins_Currencies | ForEach-Object {
                #Option 2
                [PSCustomObject]@{
                    Algorithm     = $ZergPoolCoins_Algorithm_Norm
                    Info          = $ZergPoolCoins_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = "$ZergPoolCoins_Algorithm.$ZergPoolCoins_Host"
                    Port          = $ZergPoolCoins_Port
                    User          = Get-Variable $_ -ValueOnly
                    Pass          = "$Worker,c=$_,mc=$ZergPoolCoins_Currency"
                    Region        = $ZergPoolCoins_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                }
            }
        }
    }
}
