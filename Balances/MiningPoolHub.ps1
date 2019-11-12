using module ..\Include.psm1

param(
    [String]$API_Key
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Url = "https://miningpoolhub.com/?page=account&action=balances"

if (-not $API_Key) { 
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no API key specified. "
    return
} 

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIResponse) -and $RetryCount -gt 0) { 
    try { 
        if (-not $APIResponse) { $APIResponse = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($API_Key)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop} 
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

if (($APIResponse.getuserallbalances.data | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) { 
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
} 

Write-Log -Level Verbose "Processing balances information ($Name). "
$APIResponse.getuserallbalances.data | Where-Object coin | ForEach-Object { 
    $Currency = ""
    $RetryCount = 3
    $RetryDelay = 2
    while (-not ($Currency) -and $RetryCount -gt 0) { 
        try { 
            $Currency = Invoke-RestMethod "http://$($_.coin).miningpoolhub.com/index.php?page=api&action=getpoolinfo&api_key=$($API_Key)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop | Select-Object -ExpandProperty getpoolinfo | Select-Object -ExpandProperty data | Select-Object -ExpandProperty currency
        } 
        catch { 
            Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
        } 
        $RetryCount--
    } 
    
    if (-not $Currency) { 
        Write-Log -Level Warn "Cannot determine balance for currency ($(if ($_.coin) { $_.coin}  else { "unknown"} )) - cannot convert some balances to BTC or other currencies. "
    } 
    else { 
        [PSCustomObject]@{ 
            Name        = "$($Name) ($($Currency))"
            Pool        = $Name
            Currency    = $Currency
            Balance     = $_.confirmed
            Pending     = $_.unconfirmed + $_.ae_confirmed + $_.ae_unconfirmed + $_.exchange
            Total       = $_.confirmed + $_.unconfirmed + $_.ae_confirmed + $_.ae_unconfirmed + $_.exchange
            LastUpdated = (Get-Date).ToUniversalTime()
            Url         = $Url
        } 
    } 
} 
