﻿using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

if(!$API_Key) {
    Write-Log -Level Warn "Pool API ($Name) has failed - no API key specified."
    return
}

try {
    $Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$API_Key" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    
}
catch {
    Write-Warning "Pool API ($Name) has failed. "
}

if (($Request.getuserallbalances.data | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$altcointotal = [double]0

$Request.getuserallbalances.data | Foreach-Object {
    $coinname = $_.coin
    # For coins that don't match the name on the exchange, fix up the coin name.
    switch -wildcard ($_.coin) {
        "bitcoin" {$coinname = 'BTC'}
        "myriadcoin-*" {$coinname = 'myriad'}
        "bitcoin-gold" {$coinname = 'Bitcoin Gold'}
    }

    # Convert the alt coins to BTC and add to pending balance
    if($coinname -eq 'BTC') {
        $balance = $_
    } else {
        $btcvalue = Get-BTCValue -altcoin $coinname -amount ($_.confirmed + $_.unconfirmed + $_.ae_confirmed + $_.ae_unconfirmed + $_.exchange)
        $altcointotal += $btcvalue
    }
}
[PSCustomObject]@{
     'currency' = 'BTC'
     'balance' = $balance.confirmed
     'pending' = $balance.unconfirmed + $balance.ae_confirmed + $balance.ae_unconfirmed + $balance.exchange
     'pendingalt' = $altcointotal
     'total' = $balance.confirmed + $balance.unconfirmed + $balance.ae_confirmed + $balance.ae_unconfirmed + $balance.exchange + $altcointotal
     'lastupdated' = (Get-Date)
}
#[PSCustomObject]@{
#    'currency' = 'BTC'
#    'balance' = 0
#    'pending' = $altcointotal
#    'total' = $altcointotal
#}