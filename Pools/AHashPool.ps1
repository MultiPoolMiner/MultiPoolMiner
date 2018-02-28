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

$AHashPool_Request = [PSCustomObject]@{}

if ($Info) {
    # Just return info about the pool for use in setup
    $SupportedAlgorithms = @()
    try {
        $AHashPool_Request = Invoke-RestMethod "http://www.ahashpool.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $AHashPool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Foreach-Object { 
            $SupportedAlgorithms += Get-Algorithm $_
        }
    }
    Catch {
        Write-Warning "Unable to load supported algorithms for $Name - may not be able to configure all pool settings"
        $SupportedAlgorithms = @()
    }

    return [PSCustomObject]@{
        Name = $Name
        Website = "https://ahashpool.com"
        Description = "AHashPool converts all profits to BTC"
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
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
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
