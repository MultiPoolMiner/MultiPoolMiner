using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Zpool_Request = [PSCustomObject]@{}

try {
    $Zpool_Request = Invoke-RestMethod "http://www.zpool.ca/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
}

if (($Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing. "
    return
}

$Zpool_Regions = "us"

$Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
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

    if ((Get-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm_Norm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

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
                Updated       = $Stat.Updated
            }
        }
    }
}
