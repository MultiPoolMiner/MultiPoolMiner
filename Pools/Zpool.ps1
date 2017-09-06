. .\Include.ps1

try {
    $Zpool_Request = Invoke-WebRequest "http://www.zpool.ca/api/status" -UseBasicParsing | ConvertFrom-Json
}
catch {
    return
}

if (-not $Zpool_Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Zpool_Regions = "us"

$Zpool_Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Zpool_Host = "mine.zpool.ca"
    $Zpool_Port = $Zpool_Request.$_.port
    $Zpool_Algorithm = $Zpool_Request.$_.name
    $Zpool_Algorithm_Norm = Get-Algorithm $Zpool_Algorithm
    $Zpool_Coin = ""

    $Divisor = 1000000
	
    switch ($Zpool_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h / $Divisor)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_current / $Divisor)}
	
    $Zpool_Regions | ForEach-Object {
        $Zpool_Region = $_
        $Zpool_Region_Norm = Get-Region $Zpool_Region
        
        if ($Wallet) {
            [PSCustomObject]@{
                Algorithm     = $Zpool_Algorithm_Norm
                Info          = $Zpool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$Zpool_Algorithm.$Zpool_Host"
                Port          = $Zpool_Port
                User          = $Wallet
                Pass          = "$WorkerName,c=BTC"
                Region        = $Zpool_Region_Norm
                SSL           = $false
            }
        }
    }
}
