using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Ravenminer_Regions = "us"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Ravenminer_Request = [PSCustomObject]@{}


try {
    $Ravenminer_Request = Invoke-RestMethod "https://ravenminer.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Ravenminer_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}


$Ravenminer_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Ravenminer_Request.$_.actual_last24h -gt 0} | ForEach-Object {
    $Ravenminer_Algorithm = $Ravenminer_Request.$_.name
    $Ravenminer_Algorithm_Norm = Get-Algorithm $Ravenminer_Algorithm
    $Ravenminer_Coin = "Ravencoin"
    $Ravenminer_Currency = "RVN"
    $Ravenminer_PoolFee = [Double]$Ravenminer_Request.$_.fees

    $Divisor = 1000000000

    switch ($Ravenminer_Algorithm_Norm) {
        "x16r" {$Divisor *= 1}
    }

    $Stat = Set-Stat -Name "$($Name)_$($Ravenminer_Currency)_Profit" -Value ([Double]$Ravenminer_Request.$_.actual_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $false

    $Ravenminer_Regions | ForEach-Object {
        $Ravenminer_Region = $_
        $Ravenminer_Region_Norm = Get-Region $Ravenminer_Region

        $Ravenminer_Host = "ravenminer.com"; $Ravenminer_Port = 6666
        
        [PSCustomObject]@{
            Algorithm     = $Ravenminer_Algorithm_Norm
            Info          = $Ravenminer_Coin
            Price         = $Stat.Hour # instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Ravenminer_Host
            Port          = $Ravenminer_Port
            User          = Get-Variable $Ravenminer_Currency -ValueOnly
            Pass          = "$Worker,c=$Ravenminer_Currency"
            Region        = $Ravenminer_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Ravenminer_PoolFee
        }
    }
}
