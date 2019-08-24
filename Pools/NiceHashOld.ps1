using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#Pool currenctly allows payout in BTC only
$Payout_Currencies = @("BTC") | Where-Object {$Config.Pools.$Name.Wallets.$_}

$PoolRegions = "eu", "usa", "hk", "jp", "in", "br"
$PoolAPIUri = "http://api.nicehash.com/api?method=simplemultialgo.info"

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "No wallet address for Pool ($Name) specified. Cannot mine on pool. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIRequest) {$APIRequest = Invoke-RestMethod $PoolAPIUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--        
    }
}

if (-not $APIRequest) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if ($APIRequest.result.simplemultialgo.count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

if ($Config.Pools.$Name.IsInternalWallet) {$Fee = 0.01} else {$Fee = 0.03}

$APIRequest.result.simplemultialgo | Where-Object {$_.paying -gt 0} <# algos paying 0 fail stratum #> | ForEach-Object {

    $PoolHost = "nicehash.com"
    $Port = $_.port
    $Algorithm = $_.name
    $Algorithm_Norm = Get-Algorithm $Algorithm
    $CoinName = ""
    
    if ($Algorithm -eq "Beam")   {$Algorithm_Norm = "EquihashR15050"} #temp fix
    if ($Algorithm -eq "Decred") {$Algorithm_Norm = "DecredNiceHash"} #temp fix
    if ($Algorithm -eq "Mtp")    {$Algorithm_Norm = "MtpNiceHash"} #temp fix
    if ($Algorithm -eq "Sia")    {$Algorithm_Norm = "SiaNiceHash"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$_.paying / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $PoolRegions | ForEach-Object {
        $Region = $_
        $Region_Norm = Get-Region $Region
        
        $Payout_Currencies | Where-Object {$Region -ne "eu" -and $Algorithm_Norm -ne "CryptoNightV7"<#Temp fix, No CryptonightV7 orders in Europe#>} | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $Algorithm_Norm
                CoinName      = $CoinName
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$Algorithm.$Region.$PoolHost"
                Port          = $Port
                User          = "$($Config.Pools.$Name.Wallets.$_).$($Config.Pools.$Name.Worker)"
                Pass          = "x"
                Region        = $Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                Fee           = $Fee
                PayoutScheme  = "PPLNS"
            }
            if ($Algorithm_Norm -match "Cryptonight*|Equihash.*") {
                [PSCustomObject]@{
                    Algorithm     = $Algorithm_Norm
                    CoinName      = $CoinName
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+ssl"
                    Host          = "$Algorithm.$Region.$PoolHost"
                    Port          = $Port + 30000
                    User          = "$($Config.Pools.$Name.Wallets.$_).$($Config.Pools.$Name.Worker)"
                    Pass          = "x"
                    Region        = $Region_Norm
                    SSL           = $true
                    Updated       = $Stat.Updated
                    Fee           = $Fee
                    PayoutScheme  = "PPLNS"
                }
            }
        }
    }
}
