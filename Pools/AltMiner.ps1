using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$AltMiner_Request = [PSCustomObject]@{}
$AltMinerCoins_Request = [PSCustomObject]@{}

#Define headers to get around the http:401 errors
$Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$Headers.Add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8");
    
$AltMiner_Regions = "eu"

try {
    $AltMiner_Request = Invoke-RestMethod "https://altminer.net/api/status" -UseBasicParsing -Headers $Headers -TimeoutSec 10 -ErrorAction Stop
    $AltMinerCoins_Request = Invoke-RestMethod "https://altminer.net/api/currencies" -UseBasicParsing -Headers $Headers -TimeoutSec 10 -ErrorAction Stop
    
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($AltMiner_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$AltMiner_Currencies = ($AltMinerCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}
if (($AltMiner_Currencies | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool ($Name) does not have any wallet configured. "
    return
}

$AltMiner_Currencies | Where-Object {$AltMiner_Request."$($AltMinerCoins_Request.$_.algo)".hashrate -gt 0 -and [Double]($AltMiner_Request."$($AltMinerCoins_Request.$_.algo)".estimate_current)} | ForEach-Object {

    $AltMiner_Host = "eu1.altminer.net"
    $AltMiner_Port = $AltMinerCoins_Request.$_.port
    $AltMiner_Algorithm = $AltMinerCoins_Request.$_.algo
    $AltMiner_Algorithm_Norm = Get-Algorithm $AltMiner_Algorithm
    $AltMiner_Coin = $AltMinerCoins_Request.$_.name
    $AltMiner_Currency = $_

    $Divisor = 1000000

    # per GH for sha & blake algos
    switch ($AltMiner_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($AltMiner_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($AltMiner_Algorithm_Norm)_Profit" -Value ([Double]$AltMiner_Request.$AltMiner_Algorithm.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($AltMiner_Algorithm_Norm)_Profit" -Value ([Double]$AltMiner_Request.$AltMiner_Algorithm.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $AltMiner_Regions | ForEach-Object {
        $AltMiner_Region = $_
        $AltMiner_Region_Norm = Get-Region $AltMiner_Region

        [PSCustomObject]@{
            Algorithm     = $AltMiner_Algorithm_Norm
            Info          = $AltMiner_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $AltMiner_Host
            Port          = $AltMiner_Port
            User          = Get-Variable $AltMiner_Currency -ValueOnly
            Pass          = "$Worker,c=$AltMiner_Currency"
            Region        = $AltMiner_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
        }
    }
}