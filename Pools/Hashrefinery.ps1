. .\Include.ps1

try {
    $Hashrefinery_Request = Invoke-WebRequest "http://pool.hashrefinery.com/api/status" -UseBasicParsing | ConvertFrom-Json
}
catch {
    return
}

if (-not $Hashrefinery_Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Hashrefinery_Region = "us"

$Hashrefinery_Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Hashrefinery_Host = "$_.us.hashrefinery.com"
    $Hashrefinery_Port = $Hashrefinery_Request.$_.port
    $Hashrefinery_Algorithm = Get-Algorithm $Hashrefinery_Request.$_.name
    $Hashrefinery_Coin = ""

    $Divisor = 1000000
	
    switch ($Hashrefinery_Algorithm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($Hashrefinery_Algorithm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Hashrefinery_Algorithm)_Profit" -Value ([Double]$Hashrefinery_Request.$_.estimate_last24h / $Divisor)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Hashrefinery_Algorithm)_Profit" -Value ([Double]$Hashrefinery_Request.$_.estimate_current / $Divisor)}
	
    if ($Wallet) {
        [PSCustomObject]@{
            Algorithm     = $Hashrefinery_Algorithm
            Info          = $Hashrefinery_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Hashrefinery_Host
            Port          = $Hashrefinery_Port
            User          = $Wallet 
            Pass          = "$WorkerName,c=BTC" 
            Region        = Get-Region $Hashrefinery_Region
            SSL           = $false
        }
    }
}
