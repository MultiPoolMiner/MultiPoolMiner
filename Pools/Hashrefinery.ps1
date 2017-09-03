. .\Include.ps1

try {
    $HashRefinery_Request = Invoke-WebRequest "http://pool.hashrefinery.com/api/status" -UseBasicParsing | ConvertFrom-Json
}
catch {
    return
}

if (-not $HashRefinery_Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$HashRefinery_Regions = "us"

$HashRefinery_Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $HashRefinery_Host = "hashrefinery.com"
    $HashRefinery_Port = $HashRefinery_Request.$_.port
    $HashRefinery_Algorithm = $HashRefinery_Request.$_.name
    $HashRefinery_Algorithm_Norm = Get-Algorithm $HashRefinery_Algorithm
    $HashRefinery_Coin = ""

    $Divisor = 1000000
	
    switch ($HashRefinery_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_last24h / $Divisor)}
    else {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_current / $Divisor)}
	
    $HashRefinery_Regions | ForEach-Object {
        $HashRefinery_Region = $_
        $HashRefinery_Region_Norm = Get-Region $HashRefinery_Region
        
        if ($Wallet) {
            [PSCustomObject]@{
                Algorithm     = $HashRefinery_Algorithm_Norm
                Info          = $HashRefinery_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$HashRefinery_Algorithm.$HashRefinery_Region.$HashRefinery_Host"
                Port          = $HashRefinery_Port
                User          = $Wallet
                Pass          = "$WorkerName,c=BTC"
                Region        = $HashRefinery_Region_Norm
                SSL           = $false
            }
        }
    }
}
