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

$APIUri = "https://api2.nicehash.com/main/api/v2/mining/external/$($Wallets.BTC)/rigs/"
$Sum = 0

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIResponse -and $APIResponse) -and $RetryCount -gt 0) {
    try {
        if (-not $APIResponse) {$APIResponse = Invoke-RestMethod $APIUri -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop}
    }
    catch {
        Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
    }
    $RetryCount--
}

if (-not $APIResponse) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
}
elseif (($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
}
else {
    $Sum = [Double]($APIResponse.unpaidAmount) + [Double]($APIResponse.externalBalance)
}

if ($Sum) {
    [PSCustomObject]@{
        Name        = "$Name (BTC)"
        Pool        = $Name
        Currency    = "BTC"
        Balance     = [double]($APIResponse.unpaidAmount)
        Pending     = [double]($APIResponse.externalBalance)
        Total       = $Sum
        LastUpdated = (Get-Date).ToUniversalTime()
        NextPayout  = [datetime]$APIResponse.NextPayoutTimestamp
    }
}
