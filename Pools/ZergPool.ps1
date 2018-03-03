using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [bool]$Info = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$ZergPool_Request = [PSCustomObject]@{}
$ZergPoolCurrencies_Request = [PSCustomObject]@{}

if ($Info) {
    # Just return info about the pool for use in setup
    $SupportedAlgorithms = @()
    $Currencies = @()
    try {
        $ZergPool_Request = Invoke-RestMethod "http://zerg.zergpool.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $ZergPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Foreach-Object { 
            $SupportedAlgorithms += Get-Algorithm $_
        }
    }
    catch {
        Write-Warning "Unable to load supported algorithms for $Name - may not be able to configure all pool settings"
        $SupportedAlgorithms = @()
    }
    try {
        $ZergPoolCurrencies_Request = Invoke-RestMethod 'http://zerg.zergpool.com/api/currencies' -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $Currencies = $ZergPoolCurrencies_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Select-Object -Unique 
    } 
    catch {
        Write-Warning "Unable to load currencies for $Name - may not be able to configure all pool settings"
    }

    # Define the settings this pool uses.
    $Settings = @()
    $Settings += @{Name='Worker'; Required=$true; Description='Worker name to report to pool'}
    $Settings += @{Name='BTC'; Required=$false; Description='Bitcoin payout address'}
    $Currencies | Foreach-Object {
        $Settings += @{Name=$_; Required = $false; Description = "$_ payout address"}
    }

    return [PSCustomObject]@{
        Name = $Name
        Website = "zergpool.com"
        Description = "Zergpool allows three different options for payout, but only options 1 & 2 are supported by MPM:

Option 1 - Mine in particular algorithm
This will let pool to mine most profitable coin in this algo or use merged mining benefits, and auto exchange rewards to your coin wallet. You should use coin wallet address as username.
Use c=SYMBOL in password to make sure payout wallet coin is identified correctly.
Example to mine in Scrypt algorithm and get payout in BTC
-o stratum+tcp://zergpool.com:PORT -u <YOUR_BTC_ADDRESS> -p c=BTC

Option 2 - Mine particular coin
Use your coin wallet address as username in mining software. Specify c=SYMBOL as password to idenfify payout wallet coin, and the same coin in mc=SYMBOL to specify mining coin
Example to mine Guncoin and get payout in Guncoin
-o stratum+tcp://zergpool.com:PORT -u <YOUR_GUNCOIN_WALLET_ADDRESS> -p c=GUN,mc=GUN

Option 3 - Mine particular coin with auto exchange to wallet address (not supported by MPM)
This will mine coin you specified in password field only and autoexchange it to your wallet currency for payout.
Use c=SYMBOL in password to make sure payout wallet coin is identified correctly. Use mc=SYMBOL to target particular coin for mining
Example to mine in Innova coin and get payout in LTC
-o stratum+tcp://zergpool.com:PORT -u <YOUR_LTC_ADDRESS> -p c=LTC,mc=INN"
        Algorithms = $SupportedAlgorithms
        Note = "" # Note is shown beside each pool in setup
        Settings = $Settings
    }
}

try {
    $ZergPool_Request = Invoke-RestMethod "http://api.zergpool.com:8080/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $ZergPoolCoins_Request = Invoke-RestMethod "http://api.zergpool.com:8080/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($ZergPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$ZergPool_Regions = "us", "europe"
$ZergPool_Currencies = @("BTC", "LTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}
$ZergPool_MiningCurrencies = ($ZergPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique

$ZergPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$ZergPool_Request.$_.hashrate -gt 0} |ForEach-Object {
    $ZergPool_Host = "mine.zergpool.com"
    $ZergPool_Port = $ZergPool_Request.$_.port
    $ZergPool_Algorithm = $ZergPool_Request.$_.name
    $ZergPool_Algorithm_Norm = Get-Algorithm $ZergPool_Algorithm
    $ZergPool_Coin = ""

    $Divisor = 1000000

    switch ($ZergPool_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccak" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($ZergPool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($ZergPool_Algorithm_Norm)_Profit" -Value ([Double]$ZergPool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($ZergPool_Algorithm_Norm)_Profit" -Value ([Double]$ZergPool_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $ZergPool_Regions | ForEach-Object {
        $ZergPool_Region = $_
        $ZergPool_Region_Norm = Get-Region $ZergPool_Region

        $ZergPool_Currencies | ForEach-Object {
            #Option 1
            [PSCustomObject]@{
                Algorithm     = $ZergPool_Algorithm_Norm
                Info          = $ZergPool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = if ($ZergPool_Region -eq "us") {$ZergPool_Host}else {"$ZergPool_Region.$ZergPool_Host"}
                Port          = $ZergPool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $ZergPool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}

$ZergPool_MiningCurrencies | Where-Object {$ZergPoolCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $ZergPool_Host = "mine.zergpool.com"
    $ZergPool_Port = $ZergPoolCoins_Request.$_.port
    $ZergPool_Algorithm = $ZergPoolCoins_Request.$_.algo
    $ZergPool_Algorithm_Norm = Get-Algorithm $ZergPool_Algorithm
    $ZergPool_Coin = $ZergPoolCoins_Request.$_.name
    $ZergPool_Currency = $_

    $Divisor = 1000000000

    switch ($ZergPool_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccak" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$ZergPoolCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $ZergPool_Regions | ForEach-Object {
        $ZergPool_Region = $_
        $ZergPool_Region_Norm = Get-Region $ZergPool_Region

        if (Get-Variable $ZergPool_Currency -ValueOnly -ErrorAction SilentlyContinue) {
            $ZergPool_Currency | ForEach-Object {
                #Option 3
                [PSCustomObject]@{
                    Algorithm     = $ZergPool_Algorithm_Norm
                    Info          = $ZergPool_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($ZergPool_Region -eq "us") {$ZergPool_Host}else {"$ZergPool_Region.$ZergPool_Host"}
                    Port          = $ZergPool_Port
                    User          = Get-Variable $_ -ValueOnly
                    Pass          = "$Worker,c=$_,mc=$ZergPool_Currency"
                    Region        = $ZergPool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                }
            }
        }
        else {
            $ZergPool_Currencies | ForEach-Object {
                #Option 2
                [PSCustomObject]@{
                    Algorithm     = $ZergPool_Algorithm_Norm
                    Info          = $ZergPool_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($ZergPool_Region -eq "us") {$ZergPool_Host}else {"$ZergPool_Region.$ZergPool_Host"}
                    Port          = $ZergPool_Port
                    User          = Get-Variable $_ -ValueOnly
                    Pass          = "$Worker,c=$_,mc=$ZergPool_Currency"
                    Region        = $ZergPool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                }
            }
        }
    }
}