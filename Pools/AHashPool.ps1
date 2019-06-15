﻿using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PoolRegions = "us"
$PoolAPIStatusUri = "http://www.ahashpool.com/api/status"
$PoolAPICurrenciesUri = "http://www.ahashpool.com/api/currencies"

# Guaranteed payout currencies
$Payout_Currencies = @("BTC")

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIStatusRequest -and $APICurrenciesRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIStatusRequest) {$APIStatusRequest = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue}
        if (-not $APICurrenciesRequest) {$APICurrenciesRequest  = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--        
    }
}

if (-not $APIStatusRequest) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($APIStatusRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [StatusUri] returned nothing. "
    return
}

if (($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [CurrenciesUri] returned nothing. "
    return
}

$Payout_Currencies = ($Payout_Currencies + @($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Sort-Object | Select-Object -Unique | Where-Object {$Config.Pools.$Name.Wallets.$_}

if ($Payout_Currencies) {
    $APIStatusRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APIStatusRequest.$_.hashrate -gt 0} | ForEach-Object {

        $PoolHost       = "mine.ahashpool.com"
        $Port           = $APIStatusRequest.$_.port
        $Algorithm      = $APIStatusRequest.$_.name
        $CoinName       = Get-CoinName $(if ($APIStatusRequest.$_.coins -eq 1) {$APICurrenciesRequest.$($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesRequest.$_.algo -eq $Algorithm}).Name})
        $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
        if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
        $Workers        = $APIStatusRequest.$_.workers
        $Fee            = $APIStatusRequest.$_.Fees / 100

        $Divisor = 1000000 * [Double]$APIStatusRequest.$_.mbtc_mh_factor

        if ((Get-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusRequest.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
        else {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusRequest.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

        $PoolRegions | ForEach-Object {
            $Region = $_
            $Region_Norm = Get-Region $Region
            
            $Payout_Currencies | ForEach-Object {
                [PSCustomObject]@{
                    Algorithm     = $Algorithm_Norm
                    CoinName      = $CoinName
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = "$Algorithm.$PoolHost"
                    Port          = $Port
                    User          = $Config.Pools.$Name.Wallets.$_
                    Pass          = "ID=$($Config.Pools.$Name.Worker),c=$_"
                    Region        = $Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    Fee           = $Fee
                    Workers       = [Int]$Workers
                }
            }
        }
    }
}
else { 
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
}
