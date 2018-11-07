using module ..\Include.psm1

param(
    $Config
)

$Ravenminer_Regions = "us"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$Request = [PSCustomObject]@{}

if (!$PoolConfig.RVN) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Ravenminer_Regions | ForEach-Object {
    $Ravenminer_Host = "ravenminer.com"

    $Success = $true
    try {
        if (-not ($Request = Invoke-RestMethod "https://$($Ravenminer_Host)/api/wallet?address=$($PoolConfig.RVN)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop)){throw}
    }
    catch {$Success=$false}

    if (-not $Success) {
        $Success = $true
        try {
            $Request = Invoke-WebRequest -UseBasicParsing "https://$($Ravenminer_Host)/site/wallet_results?address=$($PoolConfig.RVN)" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36" -TimeoutSec 10 -ErrorAction Stop
            if (-not ($Values = ([regex]'([\d\.]+?)\s+RVN').Matches($Request.Content).Groups | Where-Object Name -eq 1)){throw}
            $Request = [PSCustomObject]@{
                "currency" = "RVN"
                "balance" = [Double]($Values | Select-Object -Index 1).Value
                "unsold" = [Double]($Values | Select-Object -Index 0).Value
                "unpaid"   = [Double]($Values | Select-Object -Index 2).Value
            }        
        }
        catch {$Success=$false}
    }

    if (-not $Success) {
        Write-Log -Level Warn "Pool Balance API ($Name) for Region $($_) has failed. "
    }

    if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
        Write-Log -Level Warn "Pool Balance API ($Name) for Region $($_) returned nothing. "
        return
    }

    if ($Request.balance -or $Request.unsold -or $Request.unpaid) {
        [PSCustomObject]@{
            "name" = "$($Name) (RVN)"
            "region" = $_
            "currency" = $Request.currency
            "balance" = $Request.balance
            "pending" = $Request.unsold
            "total" = $Request.unpaid
            'lastupdated' = (Get-Date).ToUniversalTime()
        }
    }
}
