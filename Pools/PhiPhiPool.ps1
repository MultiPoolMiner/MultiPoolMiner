using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PhiPhiPool_Request = [PSCustomObject]@{}

try {
    $PhiPhiPool_Request = Invoke-RestMethod "http://www.phi-phi-pool.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $PhiPhiPool_Request = Invoke-RestMethod "http://www.phi-phi-pool.com/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PhiPhiPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$PhiPhiPool_Regions = "us"
$PhiPhiPool_Currencies = @("BTC") + ($PhiPhiPoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$PhiPhiPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$PhiPhiPool_Request.$_.hashrate -gt 0} |ForEach-Object {
    $PhiPhiPool_Host = "pool1.phi-phi-pool.com"
    $PhiPhiPool_Port = $PhiPhiPool_Request.$_.port
    $PhiPhiPool_Algorithm = $PhiPhiPool_Request.$_.name
    $PhiPhiPool_Algorithm_Norm = Get-Algorithm $PhiPhiPool_Algorithm
    $PhiPhiPool_Coin = ""

    $Divisor = 1000000

    switch ($PhiPhiPool_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccak" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($PhiPhiPool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($PhiPhiPool_Algorithm_Norm)_Profit" -Value ([Double]$PhiPhiPool_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($PhiPhiPool_Algorithm_Norm)_Profit" -Value ([Double]$PhiPhiPool_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $PhiPhiPool_Regions | ForEach-Object {
        $PhiPhiPool_Region = $_
        $PhiPhiPool_Region_Norm = Get-Region $PhiPhiPool_Region

        $PhiPhiPool_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $PhiPhiPool_Algorithm_Norm
                Info          = $PhiPhiPool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$PhiPhiPool_Algorithm.$PhiPhiPool_Host"
                Port          = $PhiPhiPool_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $PhiPhiPool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
