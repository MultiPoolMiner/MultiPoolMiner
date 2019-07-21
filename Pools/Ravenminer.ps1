using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Guaranteed payout currencies
$Payout_Currencies = @("RVN") | Where-Object {$Config.Pools.$Name.Wallets.$_}
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$PoolRegions = "eu", "us"
$PoolAPIStatusUri = "https://ravenminer.com/api/status"

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIStatusResponse) -and $RetryCount -gt 0) {
    try {
        $APIStatusResponse = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
    }
    $RetryCount--
}

if (-not $APIStatusResponse) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -ne 1) {
    Write-Log -Level Warn "Pool API ($Name) [StatusUri] returned invalid data. "
    return
}

$APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APIStatusResponse.$_.hashrate -gt 0} | ForEach-Object {

    $PoolHost       = "ravenminer.com"
    $Port           = $APIStatusResponse.$_.port
    $Algorithm      = $APIStatusResponse.$_.name
    $Algorithm_Norm = Get-Algorithm $Algorithm
    $Workers        = $APIStatusResponse.$_.workers
    $Fee            = $APIStatusResponse.$_.Fees / 100
    $Divisor        = 1000000000

    if ((Get-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}
    
    try {
        $EstimateCorrection = ($APIStatusResponse.$_.actual_last24h / 1000) / $APIStatusResponse.$_.estimate_last24h
    }
    catch {}

    $PoolRegions | ForEach-Object {
        $Region = $_
        $Region_Norm = Get-Region $Region
        
        $Payout_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm          = $Algorithm_Norm
                CoinName           = "RavenCoin"
                Price              = $Stat.Live
                StablePrice        = $Stat.Week
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+tcp"
                Host               = "$Region.$PoolHost"
                Port               = $Port
                User               = $Config.Pools.$Name.Wallets.$_
                Pass               = "ID=$($Config.Pools.$Name.Worker),c=$_"
                Region             = $Region_Norm
                SSL                = $false
                Updated            = $Stat.Updated
                Fee                = $Fee
                Workers            = [Int]$Workers
                MiningCurrency     = "RVN"
                EstimateCorrection = $EstimateCorrection
            }
        }
    }
}
