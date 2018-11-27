using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PoolRegions = "eu", "usa", "hk", "jp", "in", "br"
$PoolAPIUri = "http://api.nicehash.com/api?method=simplemultialgo.info"

#Pool currenctly allows payout in BTC only
$Payout_Currencies = @("BTC") | Where-Object {$Wallets.$_}


if ($Payout_Currencies) {

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
        
        
        if ($Algorithm_Norm -eq "Decred") {$Algorithm_Norm = "DecredNiceHash"} #temp fix
        if ($Algorithm_Norm -eq "Sia") {$Algorithm_Norm = "SiaNiceHash"} #temp fix

        $Divisor = 1000000000

        $Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$_.paying / $Divisor) -Duration $StatSpan -ChangeDetection $true

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
                    Host          = "$Algorithm.$Region.$PoolHost"
                    Port          = $Port
                    User          = "$($Wallets.$_).$Worker"
                    Pass          = "x"
                    Region        = $Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    Fee           = $Fee
                }
                [PSCustomObject]@{
                    Algorithm     = "$($Algorithm_Norm)-NHMP"
                    CoinName      = $CoinName
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = "nhmp.$($Region.ToLower()).nicehash.com"
                    Port          = 3200
                    User          = "$($Wallets.$_).$Worker"
                    Pass          = "x"
                    Region        = $Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    Fee           = $Fee
                }

                if ($Algorithm_Norm -match "Cryptonight*" -or $Algorithm_Norm -eq "Equihash") {
                    [PSCustomObject]@{
                        Algorithm     = $Algorithm_Norm
                        CoinName      = $CoinName
                        Price         = $Stat.Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+ssl"
                        Host          = "$Algorithm.$Region.$PoolHost"
                        Port          = $Port + 30000
                        User          = "$($Wallets.$_).$Worker"
                        Pass          = "x"
                        Region        = $Region_Norm
                        SSL           = $true
                        Updated       = $Stat.Updated
                        Fee           = $Fee
                    }
                }
            }
        }
    }
}
else {
    Write-Log -Level Verbose "No wallet address for Pool ($Name) specified. Cannot mine on pool. "
}
