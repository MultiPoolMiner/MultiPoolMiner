using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$AHashPool_Request = [PSCustomObject]@{}

try {
    $AHashPool_Request = Invoke-RestMethod "http://www.ahashpool.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($AHashPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$AHashPool_Regions = "us"
$AHashPool_Currencies = @("BTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$AHashPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$AHashPool_Request.$_.hashrate -gt 0} | ForEach-Object {
    $AHashPool_Host = "mine.ahashpool.com"
    $AHashPool_Port = $AHashPool_Request.$_.port
    $AHashPool_Algorithm = $AHashPool_Request.$_.name
    $AHashPool_Algorithm_Norm = Get-Algorithm $AHashPool_Algorithm
    $AHashPool_Coin = ""

    $Divisor = 1000000

    switch ($AHashPool_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccak" {$Divisor *= 1000}
        "lbry" {$Divisor *= 1000}
        "myrgr" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "skein" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit" -Value ([Double]$AHashPool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($AHashPool_Algorithm_Norm)_Profit" -Value ([Double]$AHashPool_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $AHashPool_Regions | ForEach-Object {
        $AHashPool_Region = $_
        $AHashPool_Region_Norm = Get-Region $AHashPool_Region

        $AHashPool_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $AHashPool_Algorithm_Norm
                Info          = $AHashPool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$AHashPool_Algorithm.$AHashPool_Host"
                Port          = $AHashPool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $AHashPool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
