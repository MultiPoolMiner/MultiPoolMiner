﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Wallets.RVN) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIRequest) {$APIRequest = Invoke-RestMethod "https://ravenminer.com/api/wallet?address=$($Wallets.RVN)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36"}
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

[PSCustomObject]@{
    Name        = "$($Name) ($($APIRequest.currency))"
    Pool        = $Name
    Currency    = $APIRequest.currency
    Balance     = $APIRequest.balance
    Pending     = $APIRequest.unsold
    Total       = $APIRequest.unpaid
    LastUpdated = (Get-Date).ToUniversalTime()
}