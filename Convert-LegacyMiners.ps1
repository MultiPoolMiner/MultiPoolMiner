#Load information about the miners
Write-Log "Getting miner information. "
# Get all the miners, get just the .Content property and add the name, version and complete fees
$MinersLegacy = @(
    if (Test-Path "MinersLegacy" -PathType Container -ErrorAction Ignore) { 
        #Strip Model information from devices -> will create only one miner instance
        if ($Config.DisableDeviceDetection) { $DevicesTmp = $Devices | ConvertTo-Json -Depth 10 | ConvertFrom-Json; $DevicesTmp | ForEach-Object { $_.Model = $_.Vendor } } else { $DevicesTmp = $Devices }
        Get-ChildItemContent "MinersLegacy" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config; Devices = $DevicesTmp; JobName = "MinersLegacy" } -Priority $(if ($RunningMiners | Where-Object { $_.DeviceName -like "CPU#*" }) { "Normal" }) | ForEach-Object { 
            $_.Content | Add-Member Name $_.Name -PassThru -Force
            $_.Content | Add-Member BaseName ($_.Name -split '-' | Select-Object -Index 0)
            $_.Content | Add-Member Version ($_.Name -split '-' | Select-Object -Index 1)
            $_.Content | Add-Member Fees @($null) -ErrorAction SilentlyContinue
            $AllMinerPaths += ($_.Content.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_.Content.Path))
        }
        Remove-Variable DevicesTmp
    }
)
$AllMinerPaths = $AllMinerPaths | Sort-Object -Unique

# Select only the ones that match our $Config.DeviceName (CPU, AMD, NVIDIA) or all of them if type is unset, 
# select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
# select only the miners that match $Config.MinerName, if specified, and don't match $Config.ExcludeMinerName
$AllMiners = @($MinersLegacy | 
    Where-Object { $UnprofitableAlgorithms -notcontains (($_.HashRates.PSObject.Properties.Name | Select-Object -Index 0) -replace 'NiceHash'<#temp fix#>) } | #filter unprofitable algorithms, allow them as secondary algo
    Where-Object { $_.HashRates.PSObject.Properties.Value -notcontains 0 } | #filter miner with 0 hashrate
    Where-Object { $_.HashRates.PSObject.Properties.Value -notcontains -1 } | #filter disabled miner (-1 hashrate)
    Where-Object { -not $Config.SingleAlgoMining -or @($_.HashRates.PSObject.Properties.Name).Count -EQ 1 } | #filter dual algo miners
    Where-Object { $Config.MinerName.Count -eq 0 -or (Compare-Object @($Config.MinerName | Select-Object) @($_.BaseName, "$($_.BaseName)_$($_.Version)", $_.Name | Select-Object -Unique) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0 } | 
    Where-Object { $Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object @($Config.ExcludeMinerName | Select-Object) @($_.BaseName, "$($_.BaseName)_$($_.Version)", $_.Name | Select-Object -Unique) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } | 
    Where-Object { -not ($Config.DisableMinersWithDevFee -and $_.Fees) } | 
    Where-Object { $Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeAlgorithm | Select-Object) @($_.HashRates.PSObject.Properties.Name -replace 'NiceHash'<#temp fix#> | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } | 
    Where-Object { $Config.MinersLegacy.$($_.BaseName)."*".ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName)."*".ExcludeAlgorithm | Select-Object) @($_.HashRates.PSObject.Properties.Name -replace 'NiceHash'<#temp fix#> | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } | 
    Where-Object { $Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeDeviceName.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeDeviceName | Select-Object) @($_.DeviceName | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } | 
    Where-Object { $Config.MinersLegacy.$($_.BaseName)."*".ExcludeDeviceName.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName)."*".ExcludeDeviceName | Select-Object) @($_.DeviceName | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 }
)

#Miner with 0 hashrate (failed benchmarking) or -1 hashrate (manually disabled in dashboard)
$InactiveMiners = @($MinersLegacy | Where-Object { $_.HashRates.PSObject.Properties.Value -contains 0 -or $_.HashRates.PSObject.Properties.Value -contains -1 } )
$InactiveMiners | ForEach-Object {
    if ($_.HashRates.PSObject.Properties.Value -contains 0) { $_ | Add-Member Reason "Failed" -ErrorAction SilentlyContinue }
    elseif ($_.HashRates.PSObject.Properties.Value -contains -1) { $_ | Add-Member Reason "Disabled" -ErrorAction SilentlyContinue }
}

$FilteredMiners = @($MinersLegacy | Where-Object { $AllMiners -notcontains $_ } | Where-Object { $InactiveMiners -notcontains $_ } )
$FilteredMiners | ForEach-Object {
    if ($UnprofitableAlgorithms -contains (($_.HashRates.PSObject.Properties.Name | Select-Object -Index 0) -replace 'NiceHash'<#temp fix#>)) { $_ | Add-Member Reason "Unprofitable Algorithm" -ErrorAction SilentlyContinue }
    elseif ($Config.SingleAlgoMining -and @($_.HashRates.PSObject.Properties.Name).Count -NE 1) { $_ | Add-Member Reason "SingleAlgoMining: true" -ErrorAction SilentlyContinue }
    elseif (-not ($Config.MinerName.Count -eq 0 -or (Compare-Object @($Config.MinerName | Select-Object) @($_.BaseName, "$($_.BaseName)_$($_.Version)", $_.Name | Select-Object -Unique) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0)) { $_ | Add-Member Reason "MinerName: $($Config.MinerName -join '; ')" -ErrorAction SilentlyContinue }
    elseif (-not ($Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object @($Config.ExcludeMinerName | Select-Object) @($_.BaseName, "$($_.BaseName)_$($_.Version)", $_.Name | Select-Object -Unique) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 )) { $_ | Add-Member Reason "ExcludeMinerName: $($Config.ExcludeMinerName -join '; ')" -ErrorAction SilentlyContinue }
    elseif ($Config.DisableMinersWithDevFee -and $_.Fees) { $_ | Add-Member Reason "DisableMinersWithDevFee: true" -ErrorAction SilentlyContinue }
    elseif (-not ($Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeAlgorithm | Select-Object) @($_.HashRates.PSObject.Properties.Name -replace 'NiceHash'<#temp fix#> | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0)) { $_ | Add-Member Reason "ExcludeAlgorithm (MinerName & Version): $($Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeAlgorithm -join '; ')" -ErrorAction SilentlyContinue }
    elseif (-not ($Config.MinersLegacy.$($_.BaseName)."*".ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName)."*".ExcludeAlgorithm | Select-Object) @($_.HashRates.PSObject.Properties.Name -replace 'NiceHash'<#temp fix#> | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0)) { $_ | Add-Member Reason "ExcludeAlgorithm (MinerName): $($Config.MinersLegacy.$($_.BaseName)."*".ExcludeAlgorithm -join '; ')" -ErrorAction SilentlyContinue }
    else { $_ | Add-Member Reason "???" -ErrorAction SilentlyContinue }
}

$AllMiners | ForEach-Object {
    $_ | Add-Member IntervalMultiplier (@(@($_.HashRates.PSObject.Properties.Name | ForEach-Object { $Config.IntervalMultiplier.$_ } | Select-Object) + 1 + $($_.IntervalMultiplier)) | Measure-Object -Maximum).Maximum -Force #default interval multiplier is 1
    $_ | Add-Member ShowMinerWindow $Config.ShowMinerWindow -ErrorAction SilentlyContinue #default ShowMinerWindow 
    $_ | Add-Member WarmupTime $Config.WarmupTime -ErrorAction SilentlyContinue #default WarmupTime is taken from config file
}

if ($API) {
    #Give API access to the information
    $API.AllMiners = $AllMiners
    $API.InactiveMiners = $InactiveMiners
    $API.FilteredMiners = $FilteredMiners
}
Remove-Variable FilteredMiners
Remove-Variable InactiveMiners

#Retrieve collected balance data
if ($Balances_Jobs) { 
    if ($Balances_Jobs | Where-Object State -NE "Completed") { Write-Log "Waiting for balances information. " }
    $Balances = @((@($Balances) + @($Balances_Jobs | Receive-Job -Wait -AutoRemoveJob -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Content | Where-Object Total -GT 0)) | Group-Object Name | ForEach-Object { $_.Group | Sort-Object LastUpdated | Select-Object -Last 1 })
    Remove-Variable Balances_Jobs
    if ($API) { $API.Balances_Jobs = $null }
}

#Update the exchange rates
Write-Log "Updating exchange rates from CryptoCompare. "
try { 
    $NewRates = Invoke-RestMethod "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$((@([PSCustomObject]@{Currency = "BTC"}) + @($Balances) | Select-Object -ExpandProperty Currency -Unique | ForEach-Object {$_.ToUpper()}) -join ",")&tsyms=$(($Config.Currency | ForEach-Object {$_.ToUpper() -replace "mBTC", "BTC"}) -join ",")&extraParams=http://multipoolminer.io" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch { 
    Write-Log -Level Warn "CryptoCompare is down. "
}
if ($NewRates) { 
    $Rates = $NewRates
    $Rates | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Rates.($_) | Add-Member $_ ([Double]1) -Force }
}
if ($Rates.BTC.BTC -ne 1) { 
    $Rates = [PSCustomObject]@{BTC = [PSCustomObject]@{BTC = [Double]1 } }
}
#Convert values to milli BTC
if ($Config.Currency -contains "mBTC" -and $Rates.BTC) { 
    $Currency = "mBTC"
    $Rates | Add-Member mBTC ($Rates.BTC | ConvertTo-Json -Depth 10 | ConvertFrom-Json) -Force
    $Rates | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object { $_ -ne "BTC" } | ForEach-Object { $Rates.$_ | Add-Member mBTC ([Double]($Rates.$_.BTC * 1000)) -ErrorAction SilentlyContinue; if ($Config.Currency -notcontains "BTC") { $Rates.$_.PSObject.Properties.Remove("BTC") } }
    $Rates.mBTC | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Rates.mBTC.$_ /= 1000 }
    $Rates.BTC | Add-Member mBTC 1000 -Force
    if ($Config.Currency -notcontains "BTC") { $Rates.BTC.PSObject.Properties.Remove("BTC") }
    $Balances | ForEach-Object { if ($_.Currency -eq "BTC") { $_.Currency = "mBTC"; $_.Balance *= 1000; $_.Pending *= 1000; $_.Total *= 1000 } }
}
else { $Currency = "BTC" }
if ($API) { 
    $API.Balances = $Balances #Give API access to the pool balances
    $API.Rates = $Rates #Give API access to the exchange rates
}

#Power price
if ($Config.PowerPrices | Sort-Object | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) { 
    if ($null -eq $Config.PowerPrices."00:00") { 
        #00:00h power price is the same as the last price of the day
        $Config.PowerPrices | Add-Member "00:00" ($Config.PowerPrices.($Config.PowerPrices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Sort-Object | Select-Object -Last 1))
    }
    $PowerPrice = [Double]($Config.PowerPrices.($Config.PowerPrices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Sort-Object | Where-Object { $_ -lt (Get-Date -Format HH:mm).ToString() } | Select-Object -Last 1))
}
if ($Rates.BTC.$FirstCurrency) { 
    if ($API) { $API.BTCRateFirstCurrency = $Rates.BTC.$FirstCurrency }
    if ($Config.MeasurePowerUsage -and $PowerPrice) {
        $PowerCostBTCperW = [Double](1 / 1000 * 24 * $PowerPrice / $Rates.BTC.$FirstCurrency)
        $BasePowerCost = [Double]($Config.BasePowerUsage / 1000 * 24 * $PowerPrice / $Rates.BTC.$FirstCurrency)
    }
}

if ($AllMiners) { Write-Log "Calculating earning$(if ($PowerPrice) {" and profit"}) for each miner$(if ($PowerPrice) {" (power cost $($FirstCurrency) $PowerPrice/kW⋅h)"}). " }
$AllMiners | ForEach-Object { 
    $Miner = $_

    $Miner_HashRates = [PSCustomObject]@{ }
    $Miner_Fees = [PSCustomObject]@{ }
    $Miner_Pools = [PSCustomObject]@{ }
    $Miner_Pools_Comparison = [PSCustomObject]@{ }
    $Miner_Earnings = [PSCustomObject]@{ }
    $Miner_Earnings_Comparison = [PSCustomObject]@{ }
    $Miner_Earnings_MarginOfError = [PSCustomObject]@{ }
    $Miner_Earnings_Bias = [PSCustomObject]@{ }
    $Miner_Earnings_Unbias = [PSCustomObject]@{ }

    $Miner.HashRates.PSObject.Properties.Name | ForEach-Object { #temp fix, must use 'PSObject.Properties' to preserve order
        $Miner_HashRates | Add-Member $_ ([Double]$Miner.HashRates.$_)
        $Miner_Fees | Add-Member $_ ([Double]$Miner.Fees.$_)
        $Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
        $Miner_Pools_Comparison | Add-Member $_ ([PSCustomObject]$Pools.$_)

        if ($Config.IgnoreFees) { $Miner_Fee_Factor = 1 } else { $Miner_Fee_Factor = 1 - $Miner.Fees.$_ }

        $Miner_Earnings | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price * $Miner_Fee_Factor)
        $Miner_Earnings_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice * $Miner_Fee_Factor)
        $Miner_Earnings_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Bias * $Miner_Fee_Factor)
        $Miner_Earnings_Unbias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Unbias * $Miner_Fee_Factor)
    }

    #Earning calculation
    $Miner_Earning = $Miner_Profit = [Double]($Miner_Earnings.PSObject.Properties.Value | Measure-Object -Sum).Sum
    $Miner_Earning_Comparison = $Miner_Profit_Comparison = [Double]($Miner_Earnings_Comparison.PSObject.Properties.Value | Measure-Object -Sum).Sum
    $Miner_Earning_Bias = $Miner_Profit_Bias = [Double]($Miner_Earnings_Bias.PSObject.Properties.Value | Measure-Object -Sum).Sum
    $Miner_Earning_Unbias = $Miner_Profit_Unbias = [Double]($Miner_Earnings_Unbias.PSObject.Properties.Value | Measure-Object -Sum).Sum

    $Miner_PowerUsage = $Stats."$($Miner.Name)$(if (@($Miner.Hashrates.PSObject.Properties.Name).Count -eq 1) {"_$($Miner.Hashrates.PSObject.Properties.Name)"})_PowerUsage".Week
    $Miner_PowerCost = 0
    if ($PowerCostBTCperW) { 
        $Miner_PowerCost = [Double]($Miner_PowerUsage * $PowerCostBTCperW)
        #Profit calculation
        $Miner_Profit = [Double]($Miner_Earning - $Miner_PowerCost)
        $Miner_Profit_Comparison = [Double]($Miner_Earning_Comparison - $Miner_PowerCost)
        $Miner_Profit_Bias = [Double]($Miner_Earning_Bias - $Miner_PowerCost)
        $Miner_Profit_Unbias = [Double]($Miner_Earning_Unbias - $Miner_PowerCost)
    }

    $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { 
        $Miner_Earnings_MarginOfError | Add-Member $_ ([Double]$Pools.$_.MarginOfError * (& { if ($Miner_Earning) { ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice) / $Miner_Earning } else { 1 } }))
    }
    $Miner_Earning_MarginOfError = [Double]($Miner_Earnings_MarginOfError.PSObject.Properties.Value | Measure-Object -Sum).Sum

    $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { 
        if (-not [String]$Miner.HashRates.$_) { 
            $Miner_HashRates.$_ = $null
            $Miner_Earnings.$_ = $null
            $Miner_Earnings_Comparison.$_ = $null
            $Miner_Earnings_Bias.$_ = $null
            $Miner_Earnings_Unbias.$_ = $null
            $Miner_Earning = $null
            $Miner_Earning_Comparison = $null
            $Miner_Earnings_MarginOfError = $null
            $Miner_Earning_Bias = $null
            $Miner_Earning_Unbias = $null

            $Miner_Profit = $null
            $Miner_Profit_Comparison = $null
            $Miner_Profit_Bias = $null
            $Miner_Profit_Unbias = $null
        }
    }

    $Miner | Add-Member HashRates $Miner_HashRates -Force
    $Miner | Add-Member Fees $Miner_Fees -Force
    $Miner | Add-Member Pools $Miner_Pools

    $Miner | Add-Member Earnings $Miner_Earnings
    $Miner | Add-Member Earnings_Comparison $Miner_Earnings_Comparison
    $Miner | Add-Member Earnings_Bias $Miner_Earnings_Bias
    $Miner | Add-Member Earnings_Unbias $Miner_Earnings_Unbias
    $Miner | Add-Member Earning $Miner_Earning
    $Miner | Add-Member Earning_Comparison $Miner_Earning_Comparison
    $Miner | Add-Member Earning_MarginOfError $Miner_Earning_MarginOfError
    $Miner | Add-Member Earning_Bias $Miner_Earning_Bias
    $Miner | Add-Member Earning_Unbias $Miner_Earning_Unbias

    $Miner | Add-Member Profit $Miner_Profit
    $Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
    $Miner | Add-Member Profit_Bias $Miner_Profit_Bias
    $Miner | Add-Member Profit_Unbias $Miner_Profit_Unbias

    $Miner | Add-Member DeviceName @($Miner.DeviceName | Select-Object -Unique | Sort-Object) -Force
    $Miner | Add-Member PowerCost $Miner_PowerCost -Force
    $Miner | Add-Member PowerUsage $Miner_PowerUsage -Force

    if ($Miner.PrerequisitePath) { $Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath) }

    if ($Miner.Arguments -isnot [String]) { $Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress }

    if (-not $Miner.API) { $Miner | Add-Member API "Miner" -Force }
    $Miner | Add-Member AllowedBadShareRatio $Config.AllowedBadShareRatio -ErrorAction SilentlyContinue
}
$Miners = @($AllMiners | Where-Object { (Test-Path $_.Path -PathType Leaf -ErrorAction Ignore) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath -PathType Leaf -ErrorAction Ignore)) })
if ($API) { $API.Miners = $Miners } #Give API access to the miners information

#Get miners needing benchmarking
$MinersNeedingBenchmark = @($Miners | Where-Object { $_.HashRates.PSObject.Properties.Value -contains $null })
if ($API) { $API.MinersNeedingBenchmark = $MinersNeedingBenchmark }

#Get miners needing power usage measurement
$MinersNeedingPowerUsageMeasurement = @($(if ($Config.MeasurePowerUsage) { @($Miners | Where-Object PowerUsage -LE 0) }))
if ($API) { $API.MinersNeedingPowerUsageMeasurement = $MinersNeedingPowerUsageMeasurement }

if ($Miners.Count -ne $AllMiners.Count -and $Downloader.State -ne "Running") { 
    Write-Log -Level Warn "Some miners binaries are missing, starting downloader. "
    $Downloader = Start-Job -Name Downloader -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList (@($AllMiners | Where-Object { $_.PrerequisitePath -and -not (Test-Path $_.PrerequisitePath -PathType Leaf -ErrorAction Ignore) } | Select-Object @{name = "URI"; expression = { $_.PrerequisiteURI } }, @{name = "Path"; expression = { $_.PrerequisitePath } }, @{name = "Searchable"; expression = { $false } }) + @($AllMiners | Where-Object { -not (Test-Path $_.Path -PathType Leaf -ErrorAction Ignore) } | Select-Object URI, Path, @{name = "Searchable"; expression = { $Miner = $_; ($AllMiners | Where-Object { (Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI }).Count -eq 0 } }) | Select-Object * -Unique) -FilePath .\Downloader.ps1
}

#Open firewall ports for all miners
#temp fix, needs removing from loop as it requires admin rights
if (Get-Command "Get-MpPreference" -ErrorAction Ignore) { 
    if ((Get-Command "Get-MpComputerStatus" -ErrorAction Ignore) -and (Get-MpComputerStatus -ErrorAction Ignore)) { 
        if (Get-Command "Get-NetFirewallRule" -ErrorAction Ignore) { 
            if ($null -eq $MinerFirewalls) { $MinerFirewalls = Get-NetFirewallApplicationFilter | Select-Object -ExpandProperty Program }
            if (@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ "=>") { 
                Start-Process (@{desktop = "powershell"; core = "pwsh" }.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'; ('$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Compress)' | ConvertFrom-Json) | ForEach-Object {New-NetFirewallRule -DisplayName (Split-Path `$_ -leaf) -Program `$_ -Description 'Inbound rule added by MultiPoolMiner $Version on $((Get-Date).ToString())' -Group 'Cryptocurrency Miner'}" -replace '"', '\"') -Verb runAs
                Remove-Variable MinerFirewalls
            }
        }
    }
}

#Apply watchdog to miners
$Miners = @(
    $Miners | Where-Object { 
        $Miner = $_
        $Miner_WatchdogTimers = @($WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval * $Miner.IntervalMultiplier) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset))
        ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object { $Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm } | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
    }
)

#Use only use the most profitable miner per algo and device. E.g. if there are several miners available to mine the same algo, only the most profitable of them will ever be used in the further calculations, all other will also be hidden in the summary screen
if (-not $Config.ShowAllMiners) { 
    $Miners = @($Miners | Where-Object { ($MinersNeedingBenchmark.DeviceName | Select-Object -Unique) -notcontains $_.DeviceName -and ($MinersNeedingPowerUsageMeasurement.DeviceName | Select-Object -Unique) -notcontains $_.DeviceName } | Sort-Object -Descending { "$($_.DeviceName -join '')$(($_.HashRates.PSObject.Properties.Name | ForEach-Object {$_ -split "-" | Select-Object -Index 0}) -join '')" }, { ($_ | Where-Object Profit -EQ $null | Measure-Object).Count }, Profit_Bias, { ($_ | Where-Object Profit -NE 0 | Measure-Object).Count } | Group-Object { "$($_.DeviceName -join '')$(($_.HashRates.PSObject.Properties.Name | ForEach-Object {$_ -split "-" | Select-Object -Index 0}) -join '')" } | ForEach-Object { $_.Group[0] }) + @($Miners | Where-Object { ($MinersNeedingBenchmark.DeviceName | Select-Object -Unique) -contains $_.DeviceName -or ($MinersNeedingPowerUsageMeasurement.DeviceName | Select-Object -Unique) -contains $_.DeviceName })
}

#Update the active miners
if ($Miners.Count -eq 0) { 
    Write-Log -Level Warn "No miners available. "
    Start-Sleep 10
    continue
}

$ActiveMiners | ForEach-Object { 
    $_.Earning = 0
    $_.Earning_Comparison = 0
    $_.Earning_MarginOfError = 0
    $_.Earning_Bias = 0
    $_.Earning_Unbias = 0
    $_.Profit = 0
    $_.Profit_Comparison = 0
    $_.Profit_Bias = 0
    $_.Profit_Unbias = 0
    $_.Best = $false
    $_.Best_Comparison = $false
}
$Miners | ForEach-Object { 
    $Miner = $_
    $ActiveMiner = $ActiveMiners | Where-Object { 
        $_.Name -eq $Miner.Name -and 
        $_.Path -eq $Miner.Path -and 
        ($_.Arguments -eq $Miner.Arguments -or ($_.New -and $_.Speed -contains $null <#Keep benchmarking miners to prevent switching#>)) -and 
        $_.API -eq $Miner.API -and 
        $_.Port -eq $Miner.Port -and 
        $_.ShowMinerWindow -eq $Miner.ShowMinerWindow -and 
        $_.IntervalMultiplier -eq $Miner.IntervalMultiplier -and 
        $_.AllowedBadShareRatio -eq $Miner.AllowedBadShareRatio -and 
        (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
    }
    if ($ActiveMiner) { 
        $ActiveMiner.Earning = $Miner.Earning
        $ActiveMiner.Earning_Comparison = $Miner.Earning_Comparison
        $ActiveMiner.Earning_MarginOfError = $Miner.Earning_MarginOfError
        $ActiveMiner.Earning_Bias = $Miner.Earning_Bias
        $ActiveMiner.Earning_Unbias = $Miner.Earning_Unbias
        $ActiveMiner.Profit = $Miner.Profit
        $ActiveMiner.Profit_Comparison = $Miner.Profit_Comparison
        $ActiveMiner.Profit_Bias = $Miner.Profit_Bias
        $ActiveMiner.Profit_Unbias = $Miner.Profit_Unbias
        $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
        $ActiveMiner.ShowMinerWindow = $Miner.ShowMinerWindow
        $ActiveMiner.PowerCost = $Miner.PowerCost
        $ActiveMiner.PowerUsage = $Miner.PowerUsage
        $ActiveMiner.WarmupTime = $(if ($Miner.Speed_Live -contains $null -or $Miner.WarmupTime -eq 0) { $Miner.WarmupTime } else { $Config.WarmupTime })
        $ActiveMiner.AllowedBadShareRatio = $Miner.AllowedBadShareRatio
    }
    else { 
        $ActiveMiners += New-Object $Miner.API -Property @{ 
            Name                  = $Miner.Name
            BaseName              = $Miner.BaseName
            Version               = $Miner.Version
            Path                  = $Miner.Path
            Arguments             = $Miner.Arguments
            API                   = $Miner.API
            Port                  = $Miner.Port
            Algorithm             = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
            Benchmarked           = 0
            DeviceName            = $Miner.DeviceName
            Earning               = $Miner.Earning
            Earning_Comparison    = $Miner.Earning_Comparison
            Earning_MarginOfError = $Miner.Earning_MarginOfError
            Earning_Bias          = $Miner.Earning_Bias
            Earning_Unbias        = $Miner.Earning_Unbias
            Profit                = $Miner.Profit
            Profit_Comparison     = $Miner.Profit_Comparison
            Profit_Bias           = $Miner.Profit_Bias
            Profit_Unbias         = $Miner.Profit_Unbias
            Speed                 = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
            Speed_Live            = $null
            Best                  = $false
            Best_Comparison       = $false
            New                   = $false
            Intervals             = @()
            PoolName              = $Miner.Pools.PSObject.Properties.Value.Name #temp fix, must use 'PSObject.Properties' to preserve order
            ShowMinerWindow       = $Miner.ShowMinerWindow
            IntervalMultiplier    = $Miner.IntervalMultiplier
            Environment           = $Miner.Environment
            PowerCost             = $Miner.PowerCost
            PowerUsage            = $Miner.PowerUsage
            WarmupTime            = $Miner.WarmupTime
            AllowedBadShareRatio  = $Miner.AllowedBadShareRatio
        }
    }
}
$ActiveMiners = @($ActiveMiners | Where-Object { $_.Earning_Bias -ne 0 -or $_.Earning -ne 0 })
