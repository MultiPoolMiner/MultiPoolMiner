. .\Include.ps1

try {
    $MiningPoolHub_Request = Invoke-WebRequest "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -UseBasicParsing | ConvertFrom-Json
}
catch {
    return
}

if (-not $MiningPoolHub_Request.success) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Locations = "Europe", "US", "Asia"

$MiningPoolHub_Request.return | ForEach-Object {
    $MiningPoolHub_Hosts = $_.host_list.split(";")
    $MiningPoolHub_Port = $_.port
    $MiningPoolHub_Algorithm = Get-Algorithm $_.algo
    $MiningPoolHub_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.coin_name -replace "-", " " -replace "_", " ")) -replace " "

    if ($MiningPoolHub_Algorithm -eq "Sia") {$MiningPoolHub_Algorithm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    if ((Get-Stat -Name "MiningPoolHubCoins_$($MiningPoolHub_Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "MiningPoolHubCoins_$($MiningPoolHub_Coin)_Profit" -Value ([Double]$_.profit / $Divisor * (1 - 0.05))}
    else {$Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Coin)_Profit" -Value ([Double]$_.profit / $Divisor)}

    $Locations | ForEach-Object {
        $Location = $_
        
        if ($UserName) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm
                Info          = $MiningPoolHub_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$UserName.$WorkerName"
                Pass          = "x"
                Location      = $Location
                SSL           = $false
            }
        
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm
                Info          = $MiningPoolHub_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Fluctuation
                Protocol      = "stratum+ssl"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$UserName.$WorkerName"
                Pass          = "x"
                Location      = $Location
                SSL           = $true
            }
        }
    }
}