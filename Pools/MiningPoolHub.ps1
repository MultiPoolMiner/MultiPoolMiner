using module ..\Include.psm1

param(
    [alias("UserName")]
    [String]$User, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [bool]$Info = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPoolHub_Request = [PSCustomObject]@{}

if ($Info) {
    # Just return info about the pool for use in setup
    $SupportedAlgorithms = @()
    try {
        $MiningPoolHub_Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $MiningPoolHub_Request.return | Foreach-Object {
            $SupportedAlgorithms += Get-Algorithm $_.algo
        }
    } Catch {
        Write-Warning "Unable to load supported algorithms for $Name - may not be able to configure all pool settings"
        $SupportedAlgorithms = @()
    }

    return [PSCustomObject]@{
        Name = $Name
        Website = "https://miningpoolhub.com"
        Description = "Payout and automatic conversion is configured through their website"
        Algorithms = $SupportedAlgorithms
        Note = "Registration required" # Note is shown beside each pool in setup
        # Define the settings this pool uses.
        Settings = @(
            @{Name='Username'; Required=$true; Description='MiningPoolHub username'},
            @{Name='Worker'; Required=$true; Description='Worker name to report to pool'},
            @{Name='API_Key'; Required=$false; Description='Used to retrieve balances'}
        )
    }
}

try {
    $MiningPoolHub_Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($MiningPoolHub_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$MiningPoolHub_Regions = "europe", "us", "asia"

$MiningPoolHub_Request.return | ForEach-Object {
    $MiningPoolHub_Hosts = $_.all_host_list.split(";")
    $MiningPoolHub_Port = $_.algo_switch_port
    $MiningPoolHub_Algorithm = $_.algo
    $MiningPoolHub_Algorithm_Norm = Get-Algorithm $MiningPoolHub_Algorithm
    $MiningPoolHub_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.current_mining_coin -replace "-", " " -replace "_", " ")) -replace " "

    if ($MiningPoolHub_Algorithm_Norm -eq "Sia") {$MiningPoolHub_Algorithm_Norm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $MiningPoolHub_Regions | ForEach-Object {
        $MiningPoolHub_Region = $_
        $MiningPoolHub_Region_Norm = Get-Region $MiningPoolHub_Region

        if ($User) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm_Norm
                Info          = $MiningPoolHub_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $MiningPoolHub_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }

            if ($MiningPoolHub_Algorithm_Norm -eq "Cryptonight" -or $MiningPoolHub_Algorithm_Norm -eq "Equihash") {
                [PSCustomObject]@{
                    Algorithm     = $MiningPoolHub_Algorithm_Norm
                    Info          = $MiningPoolHub_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+ssl"
                    Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                    Port          = $MiningPoolHub_Port
                    User          = "$User.$Worker"
                    Pass          = "x"
                    Region        = $MiningPoolHub_Region_Norm
                    SSL           = $true
                    Updated       = $Stat.Updated
                }
            }
        }
    }
}
