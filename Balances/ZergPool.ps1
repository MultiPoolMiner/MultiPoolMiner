using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Guaranteed payout currencies
$Payout_Currencies = @("BTC", "LTC", "DASH") | Where-Object {$Wallets.$_}
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIResponse) -and $RetryCount -gt 0) {
    try {
        $APIResponse = Invoke-RestMethod "http://api.zergpool.com:8080/api/currencies" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
    }
    $RetryCount--        
}

if (-not $APIResponse) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

$Payout_Currencies = (@($Payout_Currencies) + @($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) | Where-Object {$Wallets.$_} | Sort-Object -Unique
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Payout_Currencies | ForEach-Object {
    $Payout_Currency = $_
    try {
        $APIResponse = Invoke-RestMethod "http://www.zergpool.com:8080/api/wallet?address=$($Wallets.$Payout_Currency)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if (($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Warn "Pool Balance API ($Name) for $Payout_Currency returned nothing. "
        }
        else {
            [PSCustomObject]@{
                Name        = "$($Name) ($($APIResponse.currency))"
                Pool        = $Name
                Currency    = $APIResponse.currency
                Balance     = $APIResponse.balance
                Pending     = $APIResponse.unsold
                Total       = $APIResponse.unpaid
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) for $Payout_Currency has failed. "
    }
}
