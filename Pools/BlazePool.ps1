using module ..\Include.psm1

param(
    [TimeSpan]$StatSpan,
    [PSCustomObject]$Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Guaranteed payout currencies
$Payout_Currencies = @("BTC") | Where-Object {$Config.Pools.$Name.Wallets.$_}
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$PoolRegions = "us"
$PoolAPIStatusUri = "http://api.blazepool.com/status"
$PoolAPICurrenciesUri = "http://api.blazepool.com/api/currencies"

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIStatusResponse -and $APICurrenciesResponse) -and $RetryCount -gt 0) {
    try {
        if (-not $APIStatusResponse) {$APIStatusResponse = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $APICurrenciesResponse) {$APICurrenciesResponse  = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay
        $RetryCount--        
    }
}

if (-not ($APIStatusResponse -and $APICurrenciesResponse)) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [StatusUri] returned nothing. "
    return
}

if (($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) [CurrenciesUri] returned nothing. "
    return
}

$Payout_Currencies = (@($Payout_Currencies) + @($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object {$Config.Pools.$Name.Wallets.$_} | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
    return
}

$APIStatusResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APIStatusResponse.$_.hashrate -gt 0} | ForEach-Object {

    $PoolHost       = "mine.blazepool.com"
    $Port           = $APIStatusResponse.$_.port
    $Algorithm      = $APIStatusResponse.$_.name
    $CoinName       = Get-CoinName $(if ($APIStatusResponse.$_.coins -eq 1) {$APICurrenciesResponse.$($APICurrenciesResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesResponse.$_.algo -eq $Algorithm}).Name})
    $Algorithm_Norm = Get-AlgorithmFromCoinName $CoinName
    if (-not $Algorithm_Norm) {$Algorithm_Norm = Get-Algorithm $Algorithm}
    $Workers        = $APIStatusResponse.$_.workers
    $Fee            = $APIStatusResponse.$_.Fees / 100

    $Divisor = 1000000 * [Double]$APIStatusResponse.$_.mbtc_mh_factor

    if ((Get-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($Algorithm_Norm)_Profit" -Value ([Double]$APIStatusResponse.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    try {
        $EstimateCorrection = $APIStatusResponse.$_.estimate_last24h / ($APIStatusResponse.$_.actual_last24h / 1000)
    }
    catch {}

    $PoolRegions | ForEach-Object {
        $Region = $_
        $Region_Norm = Get-Region $Region
        
        $Payout_Currencies | ForEach-Object {
            [PSCustomObject]@{
                Algorithm          = $Algorithm_Norm
                CoinName           = $CoinName
                Price              = $Stat.Live
                StablePrice        = $Stat.Week
                MarginOfError      = $Stat.Week_Fluctuation
                Protocol           = "stratum+tcp"
                Host               = "$Algorithm.$PoolHost"
                Port               = $Port
                User               = $Config.Pools.$Name.Wallets.$_
                Pass               = "ID=$($Config.Pools.$Name.Worker),c=$_"
                Region             = $Region_Norm
                SSL                = $false
                Updated            = $Stat.Updated
                Fee                = $Fee
                Workers            = [Int]$Workers
                EstimateCorrection = $EstimateCorrection
            }
        }
    }
}
