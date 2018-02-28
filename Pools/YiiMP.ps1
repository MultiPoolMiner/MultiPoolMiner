using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [bool]$Info = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$YiiMPCoins_Request = [PSCustomObject]@{}

if ($Info) {
    # Just return info about the pool for use in setup
    $SupportedAlgorithms = @()
    $Currencies = @()
    try {
        $YiiMPCoins_Request = Invoke-RestMethod "http://api.yiimp.eu/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop 
        $Currencies = $YiiMPCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Select-Object -Unique
        $Currencies | Foreach-Object {
            $SupportedAlgorithms += Get-Algorithm $YiiMPCoins_Request.$_.algo
        }
    } Catch {
        Write-Warning "Unable to load supported algorithms and currencies for $Name - may not be able to configure all pool settings"
    }

    $Settings = @()
    $Settings += @{Name='Worker'; Required=$true; Description='Worker name to report to pool'}

    $Currencies | Foreach-Object {
        $Settings += @{Name=$_; Required = $false; Description = "$_ payout address"}
    }

    return [PSCustomObject]@{
        Name = $Name
        Website = "http://yiimp.eu"
        Description = "No automatic conversion. Payout in mined coins."
        Algorithms = $SupportedAlgorithms
        Note = "No automatic conversion" # Note is shown beside each pool in setup
        Settings = $Settings
    }
}

try {
    $YiiMPCoins_Request = Invoke-RestMethod "http://api.yiimp.eu/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($YiiMPCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$YiiMP_Regions = "us"
$YiiMP_Currencies = ($YiiMPCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$YiiMP_Currencies | Where-Object {$YiiMPCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $YiiMP_Host = "yiimp.eu"
    $YiiMP_Port = $YiiMPCoins_Request.$_.port
    $YiiMP_Algorithm = $YiiMPCoins_Request.$_.algo
    $YiiMP_Algorithm_Norm = Get-Algorithm $YiiMP_Algorithm
    $YiiMP_Coin = $YiiMPCoins_Request.$_.name
    $YiiMP_Currency = $_

    $Divisor = 1000000000

    switch ($YiiMP_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    $Stat = Set-Stat -Name "$($Name)_$($YiiMP_Algorithm_Norm)_Profit" -Value ([Double]$YiiMPCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $YiiMP_Regions | ForEach-Object {
        $YiiMP_Region = $_
        $YiiMP_Region_Norm = Get-Region $YiiMP_Region

        [PSCustomObject]@{
            Algorithm     = $YiiMP_Algorithm_Norm
            Info          = $YiiMP_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $YiiMP_Host
            Port          = $YiiMP_Port
            User          = Get-Variable $YiiMP_Currency -ValueOnly
            Pass          = "$Worker,c=$YiiMP_Currency"
            Region        = $YiiMP_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
        }
    }
}
