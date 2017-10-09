. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$NiceHash_Request = $null

try {
    $NiceHash_Request = Invoke-RestMethod "https://api.nicehash.com/api?method=simplemultialgo.info" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
}

$NiceHash_Regions = "eu", "usa", "hk", "jp", "in", "br"

$NiceHash_Request.result.simplemultialgo | ForEach-Object {
    $NiceHash_Host = "nicehash.com"
    $NiceHash_Port = $_.port
    $NiceHash_Algorithm = $_.name
    $NiceHash_Algorithm_Norm = Get-Algorithm $NiceHash_Algorithm
    $NiceHash_Coin = ""

    if ($NiceHash_Algorithm_Norm -eq "Sia") {$NiceHash_Algorithm_Norm = "SiaNiceHash"} #temp fix
    if ($NiceHash_Algorithm_Norm -eq "Decred") {$NiceHash_Algorithm_Norm = "DecredNiceHash"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($NiceHash_Algorithm_Norm)_Profit" -Value ([Double]$_.paying / $Divisor) -Duration $StatSpan

    $NiceHash_Regions | ForEach-Object {
        $NiceHash_Region = $_
        $NiceHash_Region_Norm = Get-Region $NiceHash_Region

        if ($Wallet) {
            [PSCustomObject]@{
                Algorithm     = $NiceHash_Algorithm_Norm
                Info          = $NiceHash_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$NiceHash_Algorithm.$NiceHash_Region.$NiceHash_Host"
                Port          = $NiceHash_Port
                User          = "$Wallet.$WorkerName"
                Pass          = "x"
                Region        = $NiceHash_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }

            [PSCustomObject]@{
                Algorithm     = $NiceHash_Algorithm_Norm
                Info          = $NiceHash_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+ssl"
                Host          = "$NiceHash_Algorithm.$NiceHash_Region.$NiceHash_Host"
                Port          = $NiceHash_Port
                User          = "$Wallet.$WorkerName"
                Pass          = "x"
                Region        = $NiceHash_Region_Norm
                SSL           = $true
                Updated       = $Stat.Updated
            }
        }
    }
}