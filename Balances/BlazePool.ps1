using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$APIWalletRequest = [PSCustomObject]@{}

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified. "
    return
}

try {
    $APIWalletRequest = Invoke-RestMethod "http://api.blazepool.com/wallet/$($PoolConfig.BTC)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($APIWalletRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
    Name        = "$($Name) ($($APIWalletRequest.currency))"
    Pool        = $Name
    Currency    = $APIWalletRequest.currency
    Balance     = $APIWalletRequest.balance
    Pending     = $APIWalletRequest.unsold
    Total       = $APIWalletRequest.total_unpaid
    LastUpdated = (Get-Date).ToUniversalTime()
}
