using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [String]$Worker,
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$PoolRegions = "europe"
$PoolAPIStatusUri = "http://www.nlpool.nl/api/status"
$PoolAPICurrenciesUri = "http://www.nlpool.nl/api/currencies"

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC") | Where-Object {$Wallets.$_}

if ($Payout_Currencies) {

    $RetryCount = 3
    $RetryDelay = 2
    while (-not ($APIStatusRequest -and $APICurrenciesRequest) -and $RetryCount -gt 0) {
        try {
            if (-not $APIStatusRequest) {$APIStatusRequest = Invoke-RestMethod $PoolAPIStatusUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
            if (-not $APICurrenciesRequest) {$APICurrenciesRequest  = Invoke-RestMethod $PoolAPICurrenciesUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        }
        catch {
            Start-Sleep -Seconds $RetryDelay
            $RetryCount--        
        }
    }

    if (-not $APIStatusRequest) {
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        return
    }

    if (($APIStatusRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
        Write-Log -Level Warn "Pool API ($Name) [StatusUri] returned nothing. "
        return
    }

    if (($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
        Write-Log -Level Warn "Pool API ($Name) [CurrenciesUri] returned nothing. "
        return
    }

    $APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$APICurrenciesRequest.$_.hashrate -gt 0} | Foreach-Object {
     
        $Algorithm = $APICurrenciesRequest.$_.algo

        # Not all algorithms are always exposed in API
        if ($APIStatusRequest.$Algorithm) {

            $APICurrenciesRequest.$_ | Add-Member Symbol $_ -ErrorAction SilentlyContinue

            $Algorithm_Norm = Get-Algorithm $Algorithm
            $PoolHost       = "mine.nlpool.nl"
            $Port           = $APICurrenciesRequest.$_.port
            $CoinName       = (Get-Culture).TextInfo.ToTitleCase(($APICurrenciesRequest.$_.name -replace "-", " " -replace "_", " ").ToLower()) -replace " "
            $MiningCurrency = $APICurrenciesRequest.$_.symbol
            $Workers        = $APICurrenciesRequest.$_.workers
            $Fee            = $APIStatusRequest.$Algorithm.Fees / 100

            $Divisor = 1000000000 * [Double]$APIStatusRequest.$Algorithm.mbtc_mh_factor

            switch ($Algorithm_Norm) {
                "Yescrypt" {$Divisor *= 100} #temp fix
            }

            $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$APICurrenciesRequest.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

            $PoolRegions | ForEach-Object {
                $Region = $_
                $Region_Norm = Get-Region $Region

                $Payout_Currencies | ForEach-Object {
                    [PSCustomObject]@{
                        Algorithm      = $Algorithm_Norm
                        CoinName       = $CoinName
                        Price          = $Stat.Live
                        StablePrice    = $Stat.Week
                        MarginOfError  = $Stat.Week_Fluctuation
                        Protocol       = "stratum+tcp"
                        Host           = "$PoolHost"
                        Port           = $Port
                        User           = $Wallets.$_
                        Pass           = "$Worker,c=$_"
                        Region         = $Region_Norm
                        SSL            = $false
                        Updated        = $Stat.Updated
                        Fee            = $Fee
                        Workers        = $Workers
                        MiningCurrency = $MiningCurrency
                    }
                }
            }
        }
    }
}
else {
    Write-Log -Level Verbose "Cannot mine on pool ($Name) - no wallet address specified. "
}
