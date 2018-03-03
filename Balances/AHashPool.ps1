using module ..\Include.psm1

param($Config)
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$MyConfig = $Config.Pools.$Name

$Request = [PSCustomObject]@{}

if(!$MyConfig.BTC) {
  Write-Log -Level Warn "Pool API ($Name) has failed - no wallet address specified."
  return
}

try {
    $Request = Invoke-RestMethod "http://www.ahashpool.com/api/wallet?address=$($MyConfig.BTC)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
}

if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}


[PSCustomObject]@{
  "currency" = $Request.currency
  "balance" = $Request.balance
  "pending" = $Request.unsold
  "total" = $Request.total_unpaid
  'lastupdated' = (Get-Date)
}