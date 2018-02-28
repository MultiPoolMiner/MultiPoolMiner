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

$Blockmunch_Request = [PSCustomObject]@{}
$BlockmunchCoins_Request = [PSCustomObject]@{}

if ($Info) {
    # Just return info about the pool for use in setup
    $SupportedAlgorithms = @()
    $Currencies = @()
    try {
        $Blockmunch_Request = Invoke-RestMethod "http://www.blockmunch.club/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $Blockmunch_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Foreach-Object { 
            $SupportedAlgorithms += Get-Algorithm $_
        }
        $BlockmunchCoins_Request = Invoke-RestMethod "http://www.blockmunch.club/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $Currencies = @("BTC") + ($BlockmunchCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique
    }
    Catch {
        Write-Warning "Unable to load supported algorithms for $Name - may not be able to configure all pool settings"
        $SupportedAlgorithms = @()
    }

    $Settings = @()
    $Settings += @{Name='Worker'; Required=$true; Description='Worker name to report to pool'}

    $Currencies | Foreach-Object {
        $Settings += @{Name=$_; Required = $false; Description = "$_ payout address"}
    }

    return [PSCustomObject]@{
        Name = $Name
        Website = "http://blockmunch.club"
        Description = "Supports autoexchange to BTC or payout in mined coins"
        Algorithms = $SupportedAlgorithms
        Note = ""
        # Define the settings this pool uses.
        Settings = $Settings
    }
}

try {
    $Blockmunch_Request = Invoke-RestMethod "http://www.blockmunch.club/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $BlockmunchCoins_Request = Invoke-RestMethod "http://www.blockmunch.club/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Blockmunch_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Blockmunch_Regions = "us"
$Blockmunch_Currencies = @("BTC") + ($BlockmunchCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$Blockmunch_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Blockmunch_Request.$_.hashrate -gt 0} | ForEach-Object {
    $Blockmunch_Host = "blockmunch.club"
    $Blockmunch_Port = $Blockmunch_Request.$_.port
    $Blockmunch_Algorithm = $Blockmunch_Request.$_.name
    $Blockmunch_Algorithm_Norm = Get-Algorithm $Blockmunch_Algorithm
    $Blockmunch_Coin = ""

    $Divisor = 1000000

    switch ($Blockmunch_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit" -Value ([Double]$Blockmunch_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Blockmunch_Algorithm_Norm)_Profit" -Value ([Double]$Blockmunch_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $Blockmunch_Regions | ForEach-Object {
        $Blockmunch_Region = $_
        $Blockmunch_Region_Norm = Get-Region $Blockmunch_Region

        $Blockmunch_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm     = $Blockmunch_Algorithm_Norm
                Info          = $Blockmunch_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $Blockmunch_Host
                Port          = $Blockmunch_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $Blockmunch_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}
