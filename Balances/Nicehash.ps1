using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Wallets.BTC) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIRequest) -and $RetryCount -gt 0) {
    try {
        #NH API does not total all of your balances for each algo up, so you have to do it with another call then total them manually.
        if (-not $APIRequest) {$APIRequest = Invoke-RestMethod "https://api.nicehash.com/api?method=stats.provider&addr=$($Wallets.BTC)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        $Sum = 0
        $APIRequest.result.stats.balance | Foreach {$Sum += $_}
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
    Name        = "$($Name) (BTC)"
    Pool        = $Name
    Currency    = "BTC"
    Balance     = $Sum
    Pending     = 0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
    Total       = $Sum
    LastUpdated = (Get-Date).ToUniversalTime()
}