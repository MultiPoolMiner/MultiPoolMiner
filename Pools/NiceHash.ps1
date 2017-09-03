. .\Include.ps1

try {
    $NiceHash_Request = Invoke-WebRequest "https://api.nicehash.com/api?method=simplemultialgo.info" -UseBasicParsing | ConvertFrom-Json
}
catch {
    return
}

if (-not $NiceHash_Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$NiceHash_Regions = "eu", "usa", "hk", "jp", "in", "br"

$NiceHash_Regions | ForEach-Object {
    $NiceHash_Region = $_
    
    $NiceHash_Request.result.simplemultialgo | ForEach-Object {
        $NiceHash_Host = "$($_.name).$NiceHash_Region.nicehash.com"
        $NiceHash_Port = $_.port
        $NiceHash_Algorithm = Get-Algorithm $_.name
        $NiceHash_Coin = ""

        $Divisor = 1000000000

        $Stat = Set-Stat -Name "$($Name)_$($NiceHash_Algorithm)_Profit" -Value ([Double]$_.paying / $Divisor)
        
        if ($Wallet) {
            if ($NiceHash_Algorithm -ne "Sia") {
                [PSCustomObject]@{
                    Algorithm     = $NiceHash_Algorithm
                    Info          = $NiceHash_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $NiceHash_Host
                    Port          = $NiceHash_Port
                    User          = "$Wallet.$WorkerName"
                    Pass          = "x"
                    Region        = Get-Region $NiceHash_Region
                    SSL           = $false
                }

                [PSCustomObject]@{
                    Algorithm     = $NiceHash_Algorithm
                    Info          = $NiceHash_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+ssl"
                    Host          = $NiceHash_Host
                    Port          = $NiceHash_Port
                    User          = "$Wallet.$WorkerName"
                    Pass          = "x"
                    Region        = Get-Region $NiceHash_Region
                    SSL           = $true
                }
            }

            [PSCustomObject]@{
                Algorithm     = "$($NiceHash_Algorithm)NiceHash"
                Info          = $NiceHash_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $NiceHash_Host
                Port          = $NiceHash_Port
                User          = "$Wallet.$WorkerName"
                Pass          = "x"
                Region        = Get-Region $NiceHash_Region
                SSL           = $false
            }

            [PSCustomObject]@{
                Algorithm     = "$($NiceHash_Algorithm)NiceHash"
                Info          = $NiceHash_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+ssl"
                Host          = $NiceHash_Host
                Port          = $NiceHash_Port
                User          = "$Wallet.$WorkerName"
                Pass          = "x"
                Region        = Get-Region $NiceHash_Region
                SSL           = $true
            }
        }
    }
}