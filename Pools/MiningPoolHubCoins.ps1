using module ..\Include.psm1

param(
    [alias("UserName")]
    [String]$User, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPoolHubCoins_Request = [PSCustomObject]@{}

#defines minimum memory required per coin, default is 4gb
$MinMem = [PSCustomObject]@{
    "Expanse"  = "2gb"
    "Soilcoin" = "2gb"
    "Ubiq"     = "2gb"
    "Musicoin" = "3gb"
}

try {
    $MiningPoolHubCoins_Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($MiningPoolHubCoins_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$MiningPoolHubCoins_Regions = "europe", "us-east", "asia"

$MiningPoolHubCoins_Request.return | Where-Object {$_.pool_hash -gt 0} | ForEach-Object {
    $MiningPoolHubCoins_Host = $_.host
    $MiningPoolHubCoins_Hosts = $_.host_list.split(";")
    $MiningPoolHubCoins_Port = $_.port
    $MiningPoolHubCoins_Algorithm = $_.algo
    $MiningPoolHubCoins_Algorithm_Norm = Get-Algorithm $MiningPoolHubCoins_Algorithm
    $MiningPoolHubCoins_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.coin_name -replace "-", " " -replace "_", " ")) -replace " "

    if ($MiningPoolHubCoins_Algorithm -eq "Equihash-BTG") $MiningPoolHubCoins_Hosts = ($_.host_list -replace ".hub.miningpoolhub", ".equihash-hub.miningpoolhub").split(";")}
    if ($MiningPoolHubCoins_Algorithm_Norm -eq "Sia") {$MiningPoolHubCoins_Algorithm_Norm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHubCoins_Coin)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $MiningPoolHubCoins_Regions | ForEach-Object {
        $MiningPoolHubCoins_Region = $_
        $MiningPoolHubCoins_Region_Norm = Get-Region ($MiningPoolHubCoins_Region -replace "^us-east$", "us")

        if ($User) {
            [PSCustomObject]@{
                Algorithm     = "$($MiningPoolHubCoins_Algorithm_Norm)$(if ($MiningPoolHubCoins_Algorithm_Norm -EQ "Ethash"){$MinMem.$MiningPoolHubCoins_Coin})"
                CoinName      = $MiningPoolHubCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHubCoins_Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $MiningPoolHubCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }

            [PSCustomObject]@{
                Algorithm     = "$($MiningPoolHubCoins_Algorithm_Norm)$(if ($MiningPoolHubCoins_Algorithm_Norm -EQ "Ethash"){$MinMem.$MiningPoolHubCoins_Coin})"
                CoinName      = $MiningPoolHubCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+ssl"
                Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHubCoins_Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $MiningPoolHubCoins_Region_Norm
                SSL           = $true
                Updated       = $Stat.Updated
            }
        }
    }
}
