using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Wallets) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC", "DASH")

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIRequest) -and $RetryCount -gt 0) {
    try {
        $APIRequest = Invoke-RestMethod "http://blockmasters.co/api/currencies" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
    }
    $RetryCount--
}

if (-not $APIRequest) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($APIRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

$Payout_Currencies = ($Payout_Currencies + @($APIRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object {$Wallets.$_} | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | Foreach-Object {
    $Payout_Currency = $_
    try {
        $APIRequest = Invoke-RestMethod "http://blockmasters.co/api/wallet?address=$($Wallets.$Payout_Currency)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if (($APIRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Warn "Pool Balance API ($Name) for $Payout_Currency returned nothing. "
        }
        else {
            [PSCustomObject]@{
                Name        = "$($Name) ($($APIRequest.currency))"
                Pool        = $Name
                Currency    = $APIRequest.currency
                Balance     = $APIRequest.balance
                Pending     = $APIRequest.unsold
                Total       = $APIRequest.unpaid
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    }
}
