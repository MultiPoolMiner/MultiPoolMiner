using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$HashRefinery_Request = [PSCustomObject]@{}

try {
    $HashRefinery_Request = Invoke-RestMethod "http://pool.hashrefinery.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $HashRefineryCoins_Request = Invoke-RestMethod "http://pool.hashrefinery.com/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if ((($HashRefinery_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) -or (($HashRefineryCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1)) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$HashRefinery_Regions = "us"

#Pool allows payout in BTC only
$HashRefinery_Currencies = @("BTC", "LTC") + ($HashRefineryCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$HashRefinery_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$ExcludeAlgorithm -inotcontains (Get-Algorithm $HashRefinery_Request.$_.name) -and $Hashrefinery_Request.$_.hashrate -gt 0} | ForEach-Object {
    $HashRefinery_Host = "hashrefinery.com"
    $HashRefinery_Port = $HashRefinery_Request.$_.port
    $HashRefinery_Algorithm = $HashRefinery_Request.$_.name
    $HashRefinery_Algorithm_Norm = Get-Algorithm $HashRefinery_Algorithm
    $HashRefinery_Coin = ""

    $Divisor = 1000000

    switch ($HashRefinery_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($HashRefinery_Algorithm_Norm)_Profit" -Value ([Double]$HashRefinery_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $HashRefinery_Regions | ForEach-Object {
        $HashRefinery_Region = $_
        $HashRefinery_Region_Norm = Get-Region $HashRefinery_Region

        $HashRefinery_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $HashRefinery_Algorithm_Norm
                Info          = $HashRefinery_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$HashRefinery_Algorithm.$HashRefinery_Region.$HashRefinery_Host"
                Port          = $HashRefinery_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $HashRefinery_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
