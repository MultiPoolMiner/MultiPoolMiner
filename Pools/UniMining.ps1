using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Unimining_Request = [PSCustomObject]@{}

try {
    $Unimining_Request = Invoke-RestMethod "http://www.unimining.net/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
    return
}

if (($Unimining_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing. "
    return
}

$Unimining_Regions = "us"

$Unimining_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
    $Unimining_Host = "mine.unimining.net"
    $Unimining_Port = $Unimining_Request.$_.port
    $Unimining_Algorithm = $Unimining_Request.$_.name
    $Unimining_Algorithm_Norm = Get-Algorithm $Unimining_Algorithm
    $Unimining_Coin = ""

    $Divisor = 1000000

    switch ($Unimining_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "keccak" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($Unimining_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Unimining_Algorithm_Norm)_Profit" -Value ([Double]$Unimining_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    else {$Stat = Set-Stat -Name "$($Name)_$($Unimining_Algorithm_Norm)_Profit" -Value ([Double]$Unimining_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

    $Unimining_Regions | ForEach-Object {
        $Unimining_Region = $_
        $Unimining_Region_Norm = Get-Region $Unimining_Region

        if ($Wallet) {
            [PSCustomObject]@{
                Algorithm     = $Unimining_Algorithm_Norm
                Info          = $Unimining_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$Unimining_Algorithm.$Unimining_Host"
                Port          = $Unimining_Port
                User          = $Wallet
                Pass          = "$WorkerName,c=BTC"
                Region        = $Unimining_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
