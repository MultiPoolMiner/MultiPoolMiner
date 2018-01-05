using module ..\Include.psm1

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

if(!$Wallet) {
  Write-Log -Level Warn "Pool API ($Name) has failed - no wallet address specified."
  return
}

try {
    $Request = Invoke-RestMethod "http://zpool.ca/api/wallet?address=$Wallet" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
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
  "total" = $Request.unpaid
  'lastupdated' = (Get-Date)
}