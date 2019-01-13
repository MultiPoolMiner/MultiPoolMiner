using module .\include.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$Config,
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$NewRates
)

$BalancesData = [PSCustomObject]@{}
$Balances = @(Get-ChildItem "Balances" -File | Where-Object {$Config.Pools.$($_.BaseName) -and ($Config.ExcludePoolName -inotcontains $_.BaseName -or $Config.ShowPoolBalancesExcludedPools)} | ForEach-Object {
    Get-ChildItemContent "Balances\$($_.Name)" -Parameters @{Config = $Config}
} | Select-Object -ExpandProperty Content | Sort-Object Name)

$BalancesData | Add-Member Balances $Balances

#Get exchgange rates for all payout currencies
if ($CurrenciesWithBalances = @($Balances.currency | Select-Object -Unique)) {
    $BalancesData | Add-Member ApiRequest "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$(($CurrenciesWithBalances | ForEach-Object {$_.ToUpper()}) -join ",")&tsyms=$(($Config.Currency | ForEach-Object {$_.ToUpper()}) -join ",")&extraParams=http://multipoolminer.io"
    try {
        $Rates = Invoke-RestMethod $BalancesData.ApiRequest -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    }
    catch {
        Write-Log -Level Warn "Pool API (CryptoCompare) has failed - cannot convert balances to other currencies. "
        $BalancesData | Add-Member Rates $Rates
        Return $BalancesData
    }

    #Add total of totals
    $Totals = [PSCustomObject]@{Name = "*Total*"}

    #Add converted values
    $Config.Currency | ForEach-Object {
        $Currency = $_.ToUpper()
        $Digits = 8
        if ($NewRates.$Currency -ne $null) {$Digits = ([math]::truncate(8 - [math]::log($NewRates.$Currency, 10)))}
        if ($Digits -gt 8) {$Digits = 8}
        $Balances | Foreach-Object {
            if ($Rates.$($_.Currency).$Currency) {
                # Add separate element with numeric value. Measure-Object can not sum strings (-f)
                $_ | Add-Member "_Value in $Currency" ($_.Total * $Rates.$($_.Currency).$Currency) -Force
                #Format to string
                $_ | Add-Member "Value in $Currency" ("{0:N$($Digits)}" -f ($_.Total * $Rates.$($_.Currency).$Currency)) -Force
            }
            else {
                $_ | Add-Member "Value in $Currency" "unknown" -Force
            }
        }
        if (($Balances."_Value in $Currency" | Measure-Object -Sum -ErrorAction Ignore).sum)  {$Totals | Add-Member "Value in $Currency" ("{0:N$($Digits)}" -f ($Balances."_Value in $Currency" | Measure-Object -Sum -ErrorAction Ignore).sum) -Force}
    }

    #Add Balance (in currency)
    $Rates.PSObject.Properties.Name | ForEach-Object {
        $Currency = $_.ToUpper()
        $Digits = 8
        if ($NewRates.$Currency -ne $null) {$Digits = ([math]::truncate(8 - [math]::log($NewRates.$Currency, 10)))}
        if ($Digits -gt 8) {$Digits = 8}
        $Balances | Foreach-Object {
            if ($Currency -eq $_.Currency) {
                # Add separate element with numeric value. Measure-Object can not sum strings (-f)
                $_ | Add-Member "_Balance ($Currency)" $_.Total
                #Format to string
                $_ | Add-Member "Balance ($Currency)" ("{0:N$($Digits)}" -f $_.Total)
            }
        }
        if (($Balances."_Balance ($Currency)" | Measure-Object -Sum).sum) {$Totals | Add-Member "Balance ($Currency)" ("{0:N$($Digits)}" -f ($Balances."_Balance ($Currency)" | Measure-Object -Sum).sum)}
        
    }

    $Balances | Foreach-Object {
        $Balance = $_
        #Format to string, cannot be done before calculations are done. Measure-Object can not sum strings (-f)
        $_.Total = ("{0:N$($Digits)}" -f $_.Total)
        #Cleanup, remove elements required for calculations
        $Balance.PSObject.Properties.Name | Where-Object {$_ -like "_*"} | ForEach-Object {$Balance.PSObject.Properties.Remove($_)}
    }

    $Balances += $Totals
    $BalancesData | Add-Member Balances $Balances -Force
    $BalancesData | Add-Member Rates $Rates
}

$BalancesData | Add-Member Updated (Get-Date) -Force
Return $BalancesData
