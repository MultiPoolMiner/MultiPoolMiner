using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPoolHubCoins_Request = [PSCustomObject]@{}

try {
    $MiningPoolHubCoins_Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
}

if (($MiningPoolHubCoins_Request.return | Measure-Object).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing. "
    return
}

$MiningPoolHubCoins_Regions = "europe", "us", "asia"

$MiningPoolHubCoins_Request.return | ForEach-Object {
    $MiningPoolHubCoins_Hosts = $_.host_list.split(";")
    $MiningPoolHubCoins_Port = $_.port
    $MiningPoolHubCoins_Algorithm = $_.algo
    $MiningPoolHubCoins_Algorithm_Norm = Get-Algorithm $MiningPoolHubCoins_Algorithm
    $MiningPoolHubCoins_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.coin_name -replace "-", " " -replace "_", " ")) -replace " "

    if ($MiningPoolHubCoins_Algorithm_Norm -eq "Sia") {$MiningPoolHubCoins_Algorithm_Norm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHubCoins_Coin)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $MiningPoolHubCoins_Regions | ForEach-Object {
        $MiningPoolHubCoins_Region = $_
        $MiningPoolHubCoins_Region_Norm = Get-Region $MiningPoolHubCoins_Region

        if ($UserName) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHubCoins_Algorithm_Norm
                Info          = $MiningPoolHubCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHubCoins_Port
                User          = "$UserName.$WorkerName"
                Pass          = "x"
                Region        = $MiningPoolHubCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }

            if ($MiningPoolHubCoins_Algorithm_Norm -eq "Cryptonight" -or $MiningPoolHubCoins_Algorithm_Norm -eq "Equihash") {
                [PSCustomObject]@{
                    Algorithm     = $MiningPoolHubCoins_Algorithm_Norm
                    Info          = $MiningPoolHubCoins_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+ssl"
                    Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                    Port          = $MiningPoolHubCoins_Port
                    User          = "$UserName.$WorkerName"
                    Pass          = "x"
                    Region        = $MiningPoolHubCoins_Region_Norm
                    SSL           = $true
                    Updated       = $Stat.Updated
                }
            }

            if ($MiningPoolHubCoins_Algorithm_Norm -eq "Ethash" -and $MiningPoolHubCoins_Coin -NotLike "*ethereum*") {
                [PSCustomObject]@{
                    Algorithm     = "$($MiningPoolHubCoins_Algorithm_Norm)2gb"
                    Info          = $MiningPoolHubCoins_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                    Port          = $MiningPoolHubCoins_Port
                    User          = "$UserName.$WorkerName"
                    Pass          = "x"
                    Region        = $MiningPoolHubCoins_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                }

                if ($MiningPoolHubCoins_Algorithm_Norm -eq "Cryptonight" -or $MiningPoolHubCoins_Algorithm_Norm -eq "Equihash") {
                    [PSCustomObject]@{
                        Algorithm     = "$($MiningPoolHubCoins_Algorithm_Norm)2gb"
                        Info          = $MiningPoolHubCoins_Coin
                        Price         = $Stat.Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+ssl"
                        Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                        Port          = $MiningPoolHubCoins_Port
                        User          = "$UserName.$WorkerName"
                        Pass          = "x"
                        Region        = $MiningPoolHubCoins_Region_Norm
                        SSL           = $true
                        Updated       = $Stat.Updated
                    }
                }
            }
        }
    }
}