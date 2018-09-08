using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$APICurrenciesRequest = [PSCustomObject]@{}
$APIWalletRequest = [PSCustomObject]@{}

try {
    $APICurrenciesRequest = Invoke-RestMethod "http://api.zergpool.com:8080/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC", "DASH")
$Payout_Currencies = $Payout_Currencies + @($APICurrenciesRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Sort-Object | Where-Object {$PoolConfig.$_}

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | Foreach-Object {
    try {
        $APIWalletRequest = Invoke-RestMethod "http://zerg.zergpool.com/api/wallet?address=$($PoolConfig.$_)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if (($APIWalletRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Warn "Pool Balance API ($Name) for $_ returned nothing. "
        }
        else {
            [PSCustomObject]@{
                Name        = "$($Name) ($($APIWalletRequest.currency))"
                Pool        = $Name
                Currency    = $APIWalletRequest.currency
                Balance     = $APIWalletRequest.balance
                Pending     = $APIWalletRequest.unsold
                Total       = $APIWalletRequest.unpaid
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) for $_ has failed. "
    }
}
