using module ..\..\Include.psm1

param(
    [PSCustomObject]$Parameters
)

$Status = [PSCustomObject]@{ 0 = "Failed"; -1 = "Disabled" }
$Data = @($Parameters.Data | ConvertFrom-Json -ErrorAction SilentlyContinue)

Switch -regex ($Parameters.Action) {
    "GetStat" {
        if ($Data.Count) {
            #Get stat files for given miner name
            if ($Parameters.MinerName) {
                @($Parameters.Algorithms -split ",") | ForEach-Object {
                    $Text +="`n$($Parameters.MinerName)_$($_)_$($Parameters.Type)`n"
                }
            }
        }
        elseif ($Parameters.Value -ne $null) {
            #Get stat files with given value
            if ($Stats = $API.Stats | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $_ -like "*$($Parameters.Type)" } | Where-Object { $API.Stats.$_.Minute -eq $Parameters.Value }) {
                $Stats | ForEach-Object { $Text += "`n$($_ -replace "_$($Parameters.Type)")" }
                if ($Parameters.Value -eq 0) { $Text += "`n`n$($Stats.Count) stat file$(if ($Stats.Count -ne 1) { "s" }) with $($Parameters.Value)$($Parameters.Unit) $($Parameters.Type). " }
                if ($Parameters.Value -eq -1) { $Text += "`n`n$($Stats.Count) disabled miner$(if ($Stats.Count -ne 1) { "s" }). " }
            }
        }
    }
    "RemoveStat|SetStat" {
        if ($Data.Count) {
            $Data | ForEach-Object {
                $DataItem = $_ | Select-Object
                $Name = $DataItem.Name
                if ($Parameters.Type -eq "PowerUsage" -or $Parameters.DataSet -eq "InactiveMiners") { Remove-Stat -Name "$($Name)_PowerUsage" }
                if ($Parameters.Type -eq "Profit") { Remove-Stat -Name "$($Name)_Profit" }
                $Algorithms = @(@(if ("Algorithm" -in $DataItem.PSObject.Properties.Name) { ($DataItem.Algorithm) } else { ($DataItem.Hashrates.PSObject.Properties.Name) }) | Select-Object)
                ForEach ($Algorithm in $Algorithms) {
                    if ($Parameters.Type -eq "HashRate") {
                        $StatName = "$($Name)_$($Algorithm)_$($Parameters.Type)"
                        Remove-Stat -Name $StatName
                        if ($Parameters.Value -ne $null) {
                            #Set stat value to Parameters.Value
                            Set-Stat -Name $StatName -Value ($Parameters.Value) -Duration 0
                        }
                    }
                }
                #Update API values
                $API.($Parameters.DataSet) | Where-Object { $_.Name -like "$Name*" -and -not (Compare-Object @($Algorithms | Select-Object) @(if ("Algorithm" -in $_.PSObject.Properties.Name) { @($_.Algorithm | Select-Object) } else { @($_.Hashrates.PSObject.Properties.Name | Select-Object) })) } | ForEach-Object {
                    if ($Parameters.Type -eq "HashRate") { 
                        #Set value
                        $_.HashRates | Select-Object | ForEach-Object { $_.$Algorithm = $Parameters.Value }
                        #Clear data in API
                        $_.Speed = @($null) * ($_.HashRates.Count + 1)
                        $_.Speed_Live = @($null) * ($_.HashRates.Count + 1)
                    }
                    if ("Reason" -in $DataItem.PSObject.Properties.Name) {
                        #Update API with new reason
                        $API.($Parameters.DataSet) | Where-Object { $_.Name -like "$Name*" -and -not (Compare-Object @($Algorithms | Select-Object) @(if ("Algorithm" -in $_.PSObject.Properties.Name) { @($_.Algorithm | Select-Object) } else { @($_.Hashrates.PSObject.Properties.Name | Select-Object) })) } | ForEach-Object {
                            $_.Reason = $Status.($Parameters.Value)
                        }
                    }
                    if (($Parameters.DataSet -eq "InactiveMiners") -eq ($Parameters.Value -eq $null) -or $Parameters.Type -eq "Profit") {
                        #Remove miner from API data
                        $API.($Parameters.DataSet) = $API.($Parameters.DataSet) | Where-Object { $_.Name -notlike "$Name*" -or (Compare-Object @($Algorithms | Select-Object) @(if ("Algorithm" -in $_.PSObject.Properties.Name) { @($_.Algorithm | Select-Object) } else { @($_.Hashrates.PSObject.Properties.Name | Select-Object) })) }
                    }
                    else {
                        if ($Parameters.Type -eq "PowerUsage")  {
                            #Clear data in API
                            if ("PowerUsage" -in $_.PSObject.Properties.Name) { $_.PowerUsage = $null }
                            if ("PowerCost" -in $_.PSObject.Properties.Name) { $_.PowerCost = $null }
                        }
                        if ($Parameters.Type -match "HashRate|PowerUsage") {
                            #Clear data in API
                            if ("Earning" -in $_.PSObject.Properties.Name) { $_.Earning = $_.Earning_Comparison = $_.Earning_Bias = $_.Earning_Unbias = $_.Earning_MarginOfError = $null }
                            if ("Earnings" -in $_.PSObject.Properties.Name) { $_.Earnings.$Algorithm = $_.Earnings_Comparison.$Algorithm = $_.Earnings_Bias.$Algorithm = $_.Earnings_Unbias.$Algorithm = $null }
                            if ("Profit" -in $_.PSObject.Properties.Name) { $_.Profit = $_.Profit_Comparison = $_.Profit_Bias = $_.Profit_Unbias = $null }
                            if ("Profit" -in $_.PSObject.Properties.Name) { $_.Profit = $_.Profit_Comparison = $_.Profit_Bias = $_.Profit_Unbias = $null }
                        }
                    }
                }
                $Text += "`n$Name {$($Algorithms -join "; ")}"
            }
            if ($Parameters.Type -eq "HashRate") {
                if ($Parameters.Value -eq $null) { 
                    $Text += "`n`nThe listed miner$(if ($Data.Count -gt 1) { "s" }) will re-benchmark on next run. "
                }
                else {
                    $Text += "`n`nThe listed miner$(if ($Data.Count -gt 1) { "s are" } else { " is" } ) $(if ($Parameters.Value -eq 0) { "marked as failed" } else { "disabled" } ). " 
                }
            }
            else {
                $Text += "`n`nThe listed miner$(if ($Data.Count -gt 1) { "s" }) will re-measure power usage on next run. "
            }
        }
        elseif ($Parameter.Value -eq $null) {
            #Remove all files
            if ($Stats = $API.Stats | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $_ -like "*$($Parameters.Type)" }) {
                $Stats | ForEach-Object { 
                    Remove-Stat -Name $_
                    $API.Stats.PSObject.Properties.Remove($_)
                }
                $Text = "`nRemoved $($Stats.Count) $($Parameters.Type) stat file$(if ($Stats.Count -ne 1) { "s" }). "
            }
        }
        elseif ($Parameter.Value) {
            #Remove stat files with given value
            if ($Stats = $API.Stats | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $_ -like "*$($Parameters.Type)" } | Where-Object { $API.Stats.$_.Minute -eq $Parameters.Value }) {
                Remove-Stat -Name $_
                $API.Stats.PSObject.Properties.Remove($_)
                $Stats | ForEach-Object { $Text += "`n$($_ -replace "_$($Parameters.Type)")" }
                if ($Parameters.Value -eq 0) { $Text += "`n`n$($Stats.Count) stat file$(if ($Stats.Count -ne 1) { "s" }) with $($Parameters.Value)$($Parameters.Unit) $($Parameters.Type). " }
                if ($Parameters.Value -eq -1) { $Text += "`n`n$($Stats.Count) disabled miner$(if ($Stats.Count -ne 1) { "s" }). " }
            }
        }
    }
}

Write-Output "<pre>"
$Text | Write-Output
Write-Output "</pre>"
