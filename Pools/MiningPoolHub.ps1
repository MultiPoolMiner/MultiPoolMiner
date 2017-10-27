using module ..\Include.psm1

param(
    [Parameter(Mandatory = $false)]
    [String]$Wallet = $null, 
    [Parameter(Mandatory = $false)]
    [String]$UserName = $null, 
    [Parameter(Mandatory = $false)]
    [String]$WorkerName = $null, 
    [Parameter(Mandatory = $false)]
    [TimeSpan]$StatSpan = $null
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPoolHub_Request = $null

try {
    $MiningPoolHub_Request = Invoke-RestMethod "https://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
}

$MiningPoolHub_Regions = "europe", "us", "asia"

$MiningPoolHub_Request.return | ForEach-Object {
    $MiningPoolHub_Hosts = $_.all_host_list.split(";")
    $MiningPoolHub_Port = $_.algo_switch_port
    $MiningPoolHub_Algorithm = $_.algo
    $MiningPoolHub_Algorithm_Norm = Get-Algorithm $MiningPoolHub_Algorithm
    $MiningPoolHub_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.current_mining_coin -replace "-", " " -replace "_", " ")) -replace " "

    if ($MiningPoolHub_Algorithm_Norm -eq "Sia") {$MiningPoolHub_Algorithm_Norm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $MiningPoolHub_Regions | ForEach-Object {
        $MiningPoolHub_Region = $_
        $MiningPoolHub_Region_Norm = Get-Region $MiningPoolHub_Region

        if ($UserName) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm_Norm
                Info          = $MiningPoolHub_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$UserName.$WorkerName"
                Pass          = "x"
                Region        = $MiningPoolHub_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }

            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm_Norm
                Info          = $MiningPoolHub_Coin
                Price         = $Stat.Day #temp fix
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+ssl"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$UserName.$WorkerName"
                Pass          = "x"
                Region        = $MiningPoolHub_Region_Norm
                SSL           = $true
                Updated       = $Stat.Updated
            }
        }
    }
}