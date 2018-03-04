using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PhiPhiPool_Request = [PSCustomObject]@{}

try {
    $PhiPhiPool_Request = Invoke-RestMethod "http://www.phi-phi-pool.com/api/status" -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
}

if (($PhiPhiPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Warning "Pool API ($Name) returned nothing. "
    return
}

$PhiPhiPool_Regions = "us"

$PhiPhiPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
    $PhiPhiPool_Host = "pool1.phi-phi-pool.com"
    $PhiPhiPool_Port = $PhiPhiPool_Request.$_.port
    $PhiPhiPool_Algorithm = $PhiPhiPool_Request.$_.name
    $PhiPhiPool_Algorithm_Norm = Get-Algorithm $PhiPhiPool_Algorithm
    $PhiPhiPool_Coin = "$PhiPhiPool_Algorithm_Norm"

    $Divisor = 1000000

    switch ($PhiPhiPool_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($PhiPhiPool_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($PhiPhiPool_Algorithm_Norm)_Profit" -Value ([Double]$PhiPhiPool_Request.$_.estimate_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    else {$Stat = Set-Stat -Name "$($Name)_$($PhiPhiPool_Algorithm_Norm)_Profit" -Value ([Double]$PhiPhiPool_Request.$_.estimate_current / $Divisor) -Duration (New-TimeSpan -Days 1)}

    $PhiPhiPool_Regions | ForEach-Object {
        $PhiPhiPool_Region = $_
        $PhiPhiPool_Region_Norm = Get-Region $PhiPhiPool_Region

        if ($Wallet) {
            [PSCustomObject]@{
                Algorithm     = $PhiPhiPool_Algorithm_Norm
                Info          = $PhiPhiPool_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $PhiPhiPool_Host
                Port          = $PhiPhiPool_Port
                User          = "$Wallet.$WorkerName"
                Pass          = "stats,c=BTC"
                Region        = $PhiPhiPool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
