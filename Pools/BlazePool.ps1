using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$BlazePool_Request = [PSCustomObject]@{}

try {
    $BlazePool_Request = Invoke-RestMethod "http://api.blazepool.com/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BlazePool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$BlazePool_Regions = "us"
$BlazePool_Currencies = @("BTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$BlazePool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$BlazePool_Request.$_.hashrate -gt 0 -and [Double]$BlazePool_Request.$_.estimate_current  -gt 0} | ForEach-Object {
    $BlazePool_Host = "$_.mine.blazepool.com"
    $BlazePool_Port = $BlazePool_Request.$_.port
    $BlazePool_Algorithm = $BlazePool_Request.$_.name
    $BlazePool_Algorithm_Norm = Get-Algorithm $BlazePool_Algorithm
    $BlazePool_Coin = ""

    $Divisor = 1000000

    switch ($BlazePool_Algorithm_Norm) {
        "blake"{$Divisor *= 1000}
        "blake2s"{$Divisor *= 1000}
        "blakecoin"{$Divisor *= 1000}
        "decred"{$Divisor *= 1000}
        "keccak"{$Divisor *= 1000}
        "keccakc"{$Divisor *= 1000}
        "quark"{$Divisor *= 1000}
        "qubit"{$Divisor *= 1000}
        "vanilla"{$Divisor *= 1000}
        "scrypt"{$Divisor *= 1000}
        "x11"{$Divisor *= 1000}
        "equihash"{$Divisor /= 1000}
        "yescrypt"{$Divisor /= 1000}
    }
    
    if ((Get-Stat -Name "$($Name)_$($BlazePool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($BlazePool_Algorithm_Norm)_Profit" -Value ([Double]$BlazePool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($BlazePool_Algorithm_Norm)_Profit" -Value ([Double]$BlazePool_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $BlazePool_Regions | ForEach-Object {
        $BlazePool_Region = $_
        $BlazePool_Region_Norm = Get-Region $BlazePool_Region

        $BlazePool_Currencies | Where-Object {Get-Variable $_ -ValueOnly} | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $BlazePool_Algorithm_Norm
                Info          = $BlazePool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $BlazePool_Host
                Port          = $BlazePool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "ID=$Worker,c=$_"
                Region        = $BlazePool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
