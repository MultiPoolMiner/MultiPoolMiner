﻿using module ..\Include.psm1

param(
    [String]$API_Key
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $API_Key) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no API key specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIRequest) -and $RetryCount -gt 0) {
    try {
        if (-not $APIRequest) {$APIRequest = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($API_Key)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
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

if (($APIRequest.getuserallbalances.data | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

$APIRequest.getuserallbalances.data | Foreach-Object {

    #Define currency
    $Currency = $_.coin
    try {
        $Currency = Invoke-RestMethod "http://$($_.coin).miningpoolhub.com/index.php?page=api&action=getpoolinfo&api_key=$($API_Key)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty getpoolinfo | Select-Object -ExpandProperty data | Select-Object -ExpandProperty currency 
        [PSCustomObject]@{
        Name        = "$($Name) ($($Currency))"
            Pool        = $Name
            Currency    = $Currency
            Balance     = $_.confirmed
            Pending     = $_.unconfirmed + $_.ae_confirmed + $_.ae_unconfirmed + $_.exchange
            Total       = $_.confirmed + $_.unconfirmed + $_.ae_confirmed + $_.ae_unconfirmed + $_.exchange
            Lastupdated = (Get-Date).ToUniversalTime()
        }
    }
    catch {
        Write-Log -Level Warn "Cannot determine balance for currency ($(if ($_.coin) {$_.coin} else {"unknown"})) - cannot convert some balances to BTC or other currencies. "
    }
}
