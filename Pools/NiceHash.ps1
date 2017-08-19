. .\Include.ps1

try {
    $NiceHash_Request = Invoke-WebRequest "https://api.nicehash.com/api?method=simplemultialgo.info" -UseBasicParsing | ConvertFrom-Json
}
catch {
    return
}

if (-not $NiceHash_Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$NiceHash_Locations = "eu", "usa", "hk", "jp", "in", "br"

$NiceHash_Locations | ForEach-Object {
    $NiceHash_Location = $_
    
    $NiceHash_Request.result.simplemultialgo | ForEach-Object {
        $NiceHash_Host = "$($_.name).$NiceHash_Location.nicehash.com"
        $NiceHash_Port = $_.port
        $NiceHash_Algorithm = Get-Algorithm $_.name
        $NiceHash_Coin = ""

        $Divisor = 1000000000

        $Stat = Set-Stat -Name "$($Name)_$($NiceHash_Algorithm)_Profit" -Value ([Double]$_.paying / $Divisor)
        
        if ($Wallet) {
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
                Location      = Get-GeoLocation $NiceHash_Location
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
                Location      = Get-GeoLocation $NiceHash_Location
                SSL           = $true
            }
        }
    }
}