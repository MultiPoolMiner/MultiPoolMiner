using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Blockmunch_Request = [PSCustomObject]@{}

try {
    $Blockmunch_Request = Invoke-RestMethod "http://www.blockmunch.club/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
    return
}

if (($Blockmunch_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing. "
    return
}

$Blockmunch_Regions = "us"

$Blockmunch_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Blockmunch_Request.$_.hashrate -gt 0} | ForEach-Object {
    $Blockmunch_Host = "blockmunch.club"
    $Blockmunch_Port = $Blockmunch_Request.$_.port
    $Blockmunch_Algorithm = $Blockmunch_Request.$_.name
    $Blockmunch_Algorithm_Norm = Get-Algorithm $Blockmunch_Algorithm
    $Blockmunch_Coin = ""

    $Divisor = 1000000

    switch ($Blockmunch_Algorithm_Norm) {
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

    if ((Get-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit" -Value ([Double]$Blockmunch_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit" -Value ([Double]$Blockmunch_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $Blockmunch_Regions | ForEach-Object {
        $Blockmunch_Region = $_
        $Blockmunch_Region_Norm = Get-Region $Blockmunch_Region

        if ($Wallet) {
            [PSCustomObject]@{
                Algorithm     = $Blockmunch_Algorithm_Norm
                Info          = $Blockmunch_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $Blockmunch_Host
                Port          = $Blockmunch_Port
                User          = $Wallet
                Pass          = "$WorkerName,c=BTC"
                Region        = $Blockmunch_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
Sleep 0
