using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Guaranteed payout currencies
$Payout_Currencies = @("BTC") | Where-Object {$Wallets.$_}
if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$APIUri   = "https://api.nicehash.com/api?method=stats.provider&addr=$($Wallets.BTC)"
$APIv2Uri = "https://api2.nicehash.com/main/api/v2/mining/external/$($Wallets.BTC)/rigs/"
$Sum = 0

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIResponse -and $APIv2Response) -and $RetryCount -gt 0) {
    try {
        if (-not $APIResponse)   {$APIResponse = Invoke-RestMethod $APIUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
        if (-not $APIv2Response) {$APIv2Response = Invoke-RestMethod $APIv2Uri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
    }
    $RetryCount--
}

if (-not $APIResponse) {
    Write-Log -Level Warn "Pool Balance API v1 ($Name) has failed. "
}
elseif (($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API v1 ($Name) returned nothing. "
}
else {
    #NH API (v1) does not total all of your balances for each algo up, so you have to do it with another call then total them manually.
    $APIResponse.result.stats.balance | ForEach-Object {$Sum += $_}
}

if (-not $APIv2Response) {
    Write-Log -Level Warn "Pool Balance API v2 ($Name) has failed. "
}
elseif (($APIv2Response | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API v2 ($Name) returned nothing. "
}
else {
    $SumV2 = [Double]($APIv2Response.unpaidAmount) + [Double]($APIv2Response.externalBalance)
}

if ($Sum) {
    [PSCustomObject]@{
        Name        = "Old$($Name) (BTC)"
        Pool        = "Old$($Name)"
        Currency    = "BTC"
        Balance     = $Sum
        Pending     = 0 # Pending is always 0 since NiceHash doesn't report unconfirmed or unexchanged profits like other pools do
        Total       = $Sum
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}

if ($SumV2) {
    [PSCustomObject]@{
        Name        = "$Name (BTC)"
        Pool        = $Name
        Currency    = "BTC"
        Balance     = [double]($APIv2Response.unpaidAmount)
        Pending     = [double]($APIv2Response.externalBalance)
        Total       = $SumV2
        LastUpdated = (Get-Date).ToUniversalTime()
        NextPayout  = [datetime]$APIv2Response.NextPayoutTimestamp
    }
}
