﻿using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$Name.User) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no username specified. "
    return
}

$PoolAPIUri= "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")"
$PoolRegions = "europe", "us-east", "asia"

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIResponse.return) -and $RetryCount -gt 0) {
    try {
        if (-not $APIResponse.return) {$APIResponse = Invoke-RestMethod $PoolAPIUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--        
    }
}

if (-not $APIResponse) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if ($APIResponse.return.count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$APIResponse.return | ForEach-Object {

    $CoinName       = $_.coin_name
    $_.algo -split "-" | ForEach-Object {$CoinName = $CoinName -replace "-$($_)", ""}
    $CoinName       = Get-CoinName $CoinName

    $PoolHosts      = @($_.host_list.split(";"))
    if ($CoinName -eq "MaxCoin" ) {$PoolHosts = @("hub.miningpoolhub.com")} #temp Fix
    $Port           = $_.port
    $Algorithm      = $_.algo
    $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
    if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}

    if ($Algorithm_Norm -eq "Sia") {$Algorithm_Norm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($CoinName)-$($Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

    if ($PoolHosts.Count -gt 1) {$Regions = $PoolRegions} else {$Regions = $Config.Region} #Do not create multiple pool objects if there is only one host

    $PoolRegions | ForEach-Object {
        $Region = $_
        $Region_Norm = Get-Region ($Region -replace "^us-east$", "us")

        [PSCustomObject]@{
            Algorithm     = $Algorithm_Norm
            CoinName      = $CoinName
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $PoolHosts | Sort-Object -Descending {$_ -ilike "$Region*"} | Select-Object -First 1
            Port          = $Port
            User          = "$($Config.Pools.$Name.User).$($Config.Pools.$Name.Worker)"
            Pass          = "x"
            Region        = $Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            Fee           = 0.9 / 100
        }
        [PSCustomObject]@{
            Algorithm     = $Algorithm_Norm
            CoinName      = $CoinName
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+ssl"
            Host          = $PoolHosts | Sort-Object -Descending {$_ -ilike "$Region*"} | Select-Object -First 1
            Port          = $Port
            User          = "$($Config.Pools.$Name.User).$($Config.Pools.$Name.Worker)"
            Pass          = "x"
            Region        = $Region_Norm
            SSL           = $true
            Updated       = $Stat.Updated
            Fee           = 0.9 / 100
        }
    }
}
