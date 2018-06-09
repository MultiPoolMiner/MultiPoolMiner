using module ..\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$Request = [PSCustomObject]@{}

if (!$PoolConfig.BTC) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

try {
    $Request = Invoke-RestMethod "http://pool.hashrefinery.com/api/wallet?address=$($PoolConfig.BTC)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
}

if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
    "currency" = $Request.currency
    "balance" = $Request.balance
    "pending" = $Request.unsold
    "total" = $Request.unpaid
    'lastupdated' = (Get-Date).ToUniversalTime()
}