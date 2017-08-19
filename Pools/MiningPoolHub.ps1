. .\Include.ps1

try {
    $MiningPoolHub_Request = Invoke-WebRequest "https://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics" -UseBasicParsing | ConvertFrom-Json
}
catch {
    return
}

if (-not $MiningPoolHub_Request.success) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$MiningPoolHub_Locations = "europe", "us", "asia"

$MiningPoolHub_Request.return | ForEach-Object {
    $MiningPoolHub_Hosts = $_.all_host_list.split(";")
    $MiningPoolHub_Port = $_.algo_switch_port
    $MiningPoolHub_Algorithm = Get-Algorithm $_.algo
    $MiningPoolHub_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.current_mining_coin -replace "-", " " -replace "_", " ")) -replace " "

    if ($MiningPoolHub_Algorithm -eq "Sia") {$MiningPoolHub_Algorithm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Algorithm)_Profit" -Value ([Double]$_.profit / $Divisor)

    $MiningPoolHub_Locations | ForEach-Object {
        $MiningPoolHub_Location = $_

        if ($UserName) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm
                Info          = $MiningPoolHub_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Location*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$UserName.$WorkerName"
                Pass          = "x"
                Location      = Get-GeoLocation $MiningPoolHub_Location
                SSL           = $false
            }
        
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm
                Info          = $MiningPoolHub_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+ssl"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Location*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$UserName.$WorkerName"
                Pass          = "x"
                Location      = Get-GeoLocation $MiningPoolHub_Location
                SSL           = $true
            }
        }
    }
}