using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [bool]$Info = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$BlazePool_Request = [PSCustomObject]@{}

if ($Info) {
    # Just return info about the pool for use in setup
    $SupportedAlgorithms = @()
    try {
        $BlazePool_Request = Invoke-RestMethod "http://api.blazepool.com/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $BlazePool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Foreach-Object { 
            $SupportedAlgorithms += Get-Algorithm $_
        }
    }
    Catch {
        Write-Warning "Unable to load supported algorithms for $Name - may not be able to configure all pool settings"
        $SupportedAlgorithms = @()
    }

    return [PSCustomObject]@{
        Name = $Name
        Website = "http://blazepool.com"
        Description = "BlazePool converts all profits to BTC"
        Algorithms = $SupportedAlgorithms
        Note = "BTC payout only" # Note is shown beside each pool in setup
        # Define the settings this pool uses.
        Settings = @(
            @{Name='BTC'; Required=$true; Description='Bitcoin payout address'},
            @{Name='Worker'; Required=$true; Description='Worker name to report to pool'}
        )
    }
}

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
        "equihash"  {$Divisor /= 1000}
        "blake2s"   {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred"    {$Divisor *= 1000}
        "keccak"    {$Divisor *= 1000}
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
                Pass          = "$Worker,c=$_"
                Region        = $BlazePool_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
