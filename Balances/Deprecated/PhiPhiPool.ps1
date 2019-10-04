using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not ($Wallets | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) -ne "BTC") { 
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$RetryCount = 3
$RetryDelay = 2
while (-not ($APIResponse) -and $RetryCount -gt 0) { 
    try { 
        if (-not $APIResponse) { $APIResponse = Invoke-RestMethod "http://phi-phi-pool.com/api/currencies" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop }
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

#Pool does not do auto conversion to BTC
$Payout_Currencies = @($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Where-Object { $Wallets.$_ } | Sort-Object -Unique
if ($Payout_Currencies) { 
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

Write-Log -Level Verbose "Processing balances information ($Name). "
$Payout_Currencies | ForEach-Object { 
    $Payout_Currency = $_
    $APIResponse = ""        
    $RetryCount = 3
    $RetryDelay = 2
    while (-not ($APIResponse) -and $RetryCount -gt 0) { 
        try { 
            $APIResponse = Invoke-RestMethod "http://api.yiimp.eu/api/wallet?address=$($Wallets.$Payout_Currency)" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        }
        catch { 
            Start-Sleep -Seconds $RetryDelay # Pool might not like immediate requests
        }
        $RetryCount--
    }

    if (($APIResponse | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) { 
        Write-Log -Level Warn "Pool Balance API ($Name) for $Payout_Currency has failed. "
        
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
