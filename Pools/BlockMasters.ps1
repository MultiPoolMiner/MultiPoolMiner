using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$RetryCount = 3
$RetryDelay = 2
while (-not ($BlockMasters_Request -and $BlockMastersCoins_Request) -and $RetryCount -gt 0) {
    try {
        if (-not $BlockMasters_Request) {$BlockMasters_Request = Invoke-RestMethod "http://blockmasters.co/api/status" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $BlockMastersCoins_Request) {$BlockMastersCoins_Request  = Invoke-RestMethod "http://blockmasters.co/api/currencies" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
        $RetryCount--        
    }
}

if (-not $BlockMasters_Request) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($BlockMasters_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$BlockMasters_Regions = "eu", "us"
$BlockMasters_Currencies = @("BTC") + ($BlockMastersCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

if (-not $BlockMasters_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$BlockMasters_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$BlockMasters_Request.$_.hashrate -gt 0} | ForEach-Object {
    $BlockMasters_Host = "blockmasters.co"
    $BlockMasters_Port = $BlockMasters_Request.$_.port
    $BlockMasters_Algorithm = $BlockMasters_Request.$_.name
    $BlockMasters_Algorithm_Norm = Get-Algorithm $BlockMasters_Algorithm
    $BlockMasters_Coin = ""

    $Divisor = 1000000 * [Double]$BlockMasters_Request.$_.mbtc_mh_factor

    switch ($BlockMasters_Algorithm_Norm) {
        "bcd" {$Divisor /= 10} #temp fix
    }

    if ((Get-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit" -Value ([Double]$BlockMasters_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($BlockMasters_Algorithm_Norm)_Profit" -Value ([Double]$BlockMasters_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $BlockMasters_Regions | ForEach-Object {
        $BlockMasters_Region = $_
        $BlockMasters_Region_Norm = Get-Region $BlockMasters_Region

        $BlockMasters_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $BlockMasters_Algorithm_Norm
                CoinName      = $BlockMasters_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$(if ($BlockMasters_Region -eq "eu") {"eu."})$BlockMasters_Host"
                Port          = $BlockMasters_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $BlockMasters_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PayoutScheme  = "PPLNS"
            }
        }
    }
}
