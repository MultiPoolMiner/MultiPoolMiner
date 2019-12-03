using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Url = "https://www.ahashpool.com/wallet.php?wallet="

# Guaranteed payout currencies
$Payout_Currencies = @("BTC") | Where-Object { $Wallets.$_ }
if (-not $Payout_Currencies) { 
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIResponse) -and $RetryCount -gt 0) { 
    try { 
        $APIResponse = Invoke-RestMethod "http://www.ahashpool.com/api/wallet?address=$($Wallets.BTC)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    }
    catch { }
    if (-not $APIResponse) { 
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
        $RetryCount--
    }
}

if (-not $APIResponse) { 
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) { 
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

Write-Log -Level Verbose "Processing balances information ($Name). "
[PSCustomObject]@{ 
    Name        = "$($Name) ($($APIResponse.currency))"
    Pool        = $Name
    Currency    = $APIResponse.currency
    Balance     = $APIResponse.balance
    Pending     = $APIResponse.unsold
    Total       = $APIResponse.total_unpaid
    LastUpdated = (Get-Date).ToUniversalTime()
    Url         = "$($Url)$($Wallets.BTC)"
}
