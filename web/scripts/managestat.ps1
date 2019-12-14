using module ..\..\Include.psm1

param(
    [PSCustomObject]$Parameters
)

$Status = [PSCustomObject]@{ 0 = "Failed"; -1 = "Disabled" }
$Data = $Parameters.Data | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($Data.Count) { 
    #Work on a defined set of stats
    Switch -regex ($Parameters.Action) { 
        "GetStat" { 
    #        if ($Data.Count) { 
    #            #Get stat files for given miner name
    #            if ($Parameters.MinerName) { 
    #                @($Parameters.Algorithms -split ", ") | ForEach-Object { 
    #                    $Text +="`n$($Parameters.MinerName)_$($_)_$($Parameters.Type)`n"
    #                }
    #            }
    #        }
            if ($Parameters.Value -ne $null) { 
                #Get stat files with given value
                if ($Stats = $API.Stats | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $_ -like "*$($Parameters.Type)" } | Where-Object { $API.Stats.$_.Minute -eq $Parameters.Value }) { 
                    $Stats | ForEach-Object { $Text += "`n$($_ -replace "_$($Parameters.Type)")" }
                    if ($Parameters.Value -eq 0) { $Text += "`n`n$($Stats.Count) stat file$(if ($Stats.Count -ne 1) { "s" }) with $($Parameters.Value)$($Parameters.Unit) $($Parameters.Type). " }
                    if ($Parameters.Value -eq -1) { $Text += "`n`n$($Stats.Count) disabled miner$(if ($Stats.Count -ne 1) { "s" }). " }
                }
            }
        }
        "RemoveStat|SetStat" { 
            Switch -regex ($Parameters.Type) {
                "Profit" { 
                    $Data | Where-Object Reason -ne "Unprofitable Algorithm" | ForEach-Object { 
                        $DataItem = $_ | Select-Object
                        $StatName = "$($DataItem.Name)_$(($DataItem.CurrencySymbol | Select-Object), ($DataItem.Algorithm | Select-Object) -join '-')_$($Parameters.Type)"
                        Remove-Stat -Name $StatName
                        #Remove pool from API data
                        $API."AllPools" = $API."AllPools" | Where-Object { $_.Name -ne $DataItem.Name -or $_.CurrencySymbol -ne $DataItem.CurrencySymbol -or $_.Algorithm -ne $DataItem.Algorithm }
                        $API."Pools".PSObject.Members.Remove($DataItem.Algorithm)
                    }
                    $Text += "`n`nData reset for $($Data.Count) pool$(if ($Data.Count -gt 1) { "s" }). "
                }
                "Hashrate|PowerUsage" {
                    $Data | ForEach-Object { 
                        $DataItem = $_ | Select-Object
                        $Name = $DataItem.Name
                        $Algorithms = $DataItem.Algorithms
                        if ($Parameters.Type -eq "HashRate") { 
                           #Set always requires a remove to re-init duration
                           ForEach ($Algorithm in $Algorithms) { 
                                $StatName = "$($Name)_$($Algorithm)_$($Parameters.Type)"
                                Remove-Stat -Name $StatName
                                if ($Parameters.Value -ne $null) { 
                                    #Set stat value
                                    Set-Stat -Name $StatName -Value ($Parameters.Value) -Duration 0
                                }
                            }
                        }
                        #Re-benchmark will also re-measure power usage
                        if ($Algorithms.Count -gt 1) { $StatName = "$($Name)_PowerUsage" }
                        else { $StatName = "$($Name)_$($Algorithms[0])_PowerUsage" }
                        Remove-Stat -Name $StatName
                        
                        $API."ActiveMiners" = $API."ActiveMiners" | ForEach-Object {
                            if ($_.Name -like "$Name*" -and -not (Compare-Object @($Algorithms | Select-Object) @($_.Algorithm | Select-Object))) { 
                                if ($Parameters.Value -eq $null) { 
                                    if ($Parameters.Type -eq "HashRate") { 
                                        #Clear speed and earning data in API
                                        $_.Earning = $_.Earning_Comparison = $_.Earning_Bias = $_.Earning_Unbias = $_.Earning_MarginOfError = $null
                                        $_.Speed = @($null) * ($_.Algorithm.Count + 1); $_.Speed_Live = @($null) * ($_.Algorithm.Count + 1)
                                    }
                                    #Clear profit & power data in API
                                    $_.Profit = $_.Profit_Comparison = $_.Profit_Bias = $_.Profit_Unbias = $null
                                    $_.PowerUsage = $null; $_.PowerCost = $null
                                    #Keep record in API
                                    $_
                                }
                            }
                            else { $_ <#Keep record in API#>}
                        }

                        $API."InactiveMiners" = $API."InactiveMiners" | ForEach-Object {
                            if ($_.Name -like "$Name*" -and -not (Compare-Object @($Algorithms | Select-Object) @($_.Hashrates.PSObject.Properties.Name | Select-Object))) { 
                                if ($Parameters.Value -ne $null) { 
                                    #Miner has been set as disabled or failed
                                    #Update API with new Reason value
                                    $_.Reason = $Status.($Parameters.Value)
                                    #Update API with new HashRate value
                                    ForEach ($Algorithm in $Algorithms) { 
                                        $_.Hashrates.$Algorithm = $Parameters.Value
                                    }
                                    #Keep record in API
                                    $_ 
                                } 
                            }
                            else { $_ <#Keep recordin API#>}
                        }

                        $API."Miners" = $API."Miners" | ForEach-Object { 
                            if ($_.Name -like "$Name*" -and -not (Compare-Object @($Algorithms | Select-Object) @($_.Hashrates.PSObject.Properties.Name | Select-Object))) { 
                                if ($Parameters.Type -eq "HashRate") { 
                                    #Clear speed and earning data in API
                                    ForEach ($Algorithm in $Algorithms) { 
                                        $_.Hashrates.$Algorithm = $Parameters.Value
                                    }
                                    $_.Earning = $_.Earning_Comparison = $_.Earning_Bias = $_.Earning_Unbias = $_.Earning_MarginOfError = $null
                                    ForEach ($Algorithm in $Algorithms) { 
                                        $_.Earnings.$Algorithm = $_.Earnings_Comparison.$Algorithm = $_.Earnings_Bias.$Algorithm = $_.Earnings_Unbias.$Algorithm = $null
                                    }
                                    
                                }
                                #Clear profit & power data in API
                                $_.Profit = $_.Profit_Comparison = $_.Profit_Bias = $_.Profit_Unbias = $null
                                $_.PowerUsage = $null; $_.PowerCost = $null
                            }
                            #Always keep record in API
                            $_ 
                        }

                        if ($_.Reason -eq "Failed" -or $_.Reason -eq "Disabled") { $Text += "`n$Name {$($Algorithms -join "; ")}" }

                    }
                }
            }
            if ($Parameters.Type -eq "HashRate") { 
                if ($Parameters.Value -eq $null) { 
                    $Text += "`n`nThe listed $(if ($Data.Count -eq 1) { "miner"} else { "$($Data.Count) miners" }) will re-benchmark. "
                }
                else { 
                    $Text += "`n`nThe listed $(if ($Data.Count -eq 1) { "miner is"} else { "$($Data.Count) miners are" }) $(if ($Parameters.Value -eq 0) { " marked as failed" } else { "disabled" } ). " 
                }
            }
            if ($Parameters.Type -eq "PowerUsage") { 
                $Text += "`n`nThe listed $(if ($Data.Count -eq 1) { "miner"} else { "$($Data.Count) miners" }) will re-measure power usage. "
            }
        }
    }
}
else {
    #Work an all stats matching a criteria
    if ($Parameters.Value -eq $null) { 
        #Remove all stat files, no matter what value
        if ($Stats = $API.Stats | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $_ -like "*$($Parameters.Type)" }) { 
            $Stats | ForEach-Object { 
                Remove-Stat -Name $_
                $API.Stats.PSObject.Properties.Remove($_)
            }
            $Text = "`nRemoved $($Stats.Count) $($Parameters.Type) stat file$(if ($Stats.Count -ne 1) { "s" }). "
        }
    }
    if ($Parameters.Value) { 
        #Remove stat files with given value
        if ($Stats = $API.Stats | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $_ -like "*$($Parameters.Type)" } | Where-Object { $API.Stats.$_.Minute -eq $Parameters.Value }) { 
            $Stats | ForEach-Object { 
                Remove-Stat -Name $_
                $API.Stats.PSObject.Properties.Remove($_)
                $Text += "`n$($_ -replace "_$($Parameters.Type)")"
            }
            if ($Parameters.Value -eq 0) { $Text += "`n`n$($Stats.Count) stat file$(if ($Stats.Count -ne 1) { "s" }) with $($Parameters.Value)$($Parameters.Unit) $($Parameters.Type). " }
            if ($Parameters.Value -eq -1) { $Text += "`n`n$($Stats.Count) disabled miner$(if ($Stats.Count -ne 1) { "s" }). " }
        }
    }
}

Write-Output "<pre>"
$Text | Write-Output
Write-Output "</pre>"
