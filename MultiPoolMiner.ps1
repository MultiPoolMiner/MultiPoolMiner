using module .\Include.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [Alias("BTC")]
    [String]$Wallet, 
    [Parameter(Mandatory = $false)]
    [Alias("User")]
    [String]$UserName, 
    [Parameter(Mandatory = $false)]
    [Alias("Worker")]
    [String]$WorkerName = "multipoolminer", 
    [Parameter(Mandatory = $false)]
    [Int]$API_ID = 0, 
    [Parameter(Mandatory = $false)]
    [String]$API_Key = "", 
    [Parameter(Mandatory = $false)]
    [Int]$Interval = 60, #seconds of main MPM loop (getting stats, getting miners info, calulating best miners, gethering hashrates, saving hashrates)
    [Parameter(Mandatory = $false)]
    [Alias("Location")]
    [String]$Region = "europe", #europe/us/asia
    [Parameter(Mandatory = $false)]
    [Switch]$SSL = $false, 
    [Parameter(Mandatory = $false)]
    [Alias("Device", "Type")]
    [String[]]$DeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.
    [Parameter(Mandatory = $false)]
    [String[]]$ExcludeDeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc. will not be used for mining
    [Parameter(Mandatory = $false)]
    [String[]]$Algorithm = @(), #i.e. Ethash, Equihash, CryptonightV7 etc.
    [Parameter(Mandatory = $false)]
    [String[]]$CoinName = @(), #i.e. Monero, Zcash etc.
    [Parameter(Mandatory = $false)]
    [String[]]$MiningCurrency = @(), #i.e. LUX, XVG etc.
    [Parameter(Mandatory = $false)]
    [Alias("Miner")]
    [String[]]$MinerName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("Pool")]
    [String[]]$PoolName = @(), 
    [Parameter(Mandatory = $false)]
    [String[]]$ExcludeAlgorithm = @(), #i.e. Ethash, Equihash, CryptonightV7 etc.
    [Parameter(Mandatory = $false)]
    [String[]]$ExcludeCoinName = @(), #i.e. Monero, Zcash etc.
    [Parameter(Mandatory = $false)]
    [String[]]$ExcludeMiningCurrency = @(), #i.e. LUX, XVG etc.
    [Parameter(Mandatory = $false)]
    [Alias("ExcludeMiner")]
    [String[]]$ExcludeMinerName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("ExcludePool")]
    [String[]]$ExcludePoolName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("DisableDualMining")]
    [Switch]$SingleAlgoMining = $false, #disables all dual mining miners
    [Parameter(Mandatory = $false)]
    [String[]]$Currency = ("BTC", "USD"), #i.e. GBP, EUR, ZEC, ETH etc., the first currency listed will be used as base currency for profit calculations
    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 1440)]
    [Int]$Donate = 24, #Minutes per Day, Allowed values: 10 - 1440
    [Parameter(Mandatory = $false)]
    [String]$Proxy = "", #i.e http://192.0.0.1:8080
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 10)]
    [Int]$Delay = 0, #seconds before opening each miner. Allowed values: 0 - 10
    [Parameter(Mandatory = $false)]
    [Switch]$Watchdog = $false, 
    [Parameter(Mandatory = $false)]
    [Alias("Uri", "Url")]
    [String]$MinerStatusUrl = "", #i.e https://multipoolminer.io/monitor/miner.php
    [Parameter(Mandatory = $false)]
    [String]$MinerStatusKey = "", 
    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 300)]
    [Double]$ReportStatusInterval = 90, #seconds until next miner status update. Allowed values 30 - 300, 0 to disable
    [Parameter(Mandatory = $false)]
    [Double]$SwitchingPrevention = 1, #zero does not prevent miners switching
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1)]
    [Double]$MinAccuracy = 0.5, #Only pools with price accuracy greater than the configured value. Allowed values: 0.0 - 1.0 (0% - 100%)
    [Parameter(Mandatory = $false)]
    [Switch]$ShowMinerWindow = $false, #if true most miner windows will be visible (they can steal focus) - miners that use the 'Wrapper' API will still remain hidden
    [Parameter(Mandatory = $false)]
    [Switch]$ShowAllMiners = $false, #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    [Parameter(Mandatory = $false)]
    [Switch]$IgnoreFees = $false, #if $true MPM will ignore miner and pool fees for its calculations (as older versions did)
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 999)]
    [Int]$PoolBalancesUpdateInterval = 15, #MPM will force update balances every n minutes to limit pool API requests (but never more than ONCE per loop). Allowed values 1 - 999 minutes
    [Parameter(Mandatory = $false)]
    [Switch]$DisableDeviceDetection = $false, #if true MPM won't create separate miner instances per device model. This will decrease profitability.
    [Parameter(Mandatory = $false)]
    [String]$ConfigFile = ".\Config.txt", #default config file
    [ValidateRange(5, 20)]
    [Int]$HashRateSamplesPerInterval = 10, #approx number of hashrate samples that MPM will collect per interval (higher numbers produce more exact numbers, but use more CPU cycles and memory). Allowed values: 5 - 20
    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 300)]
    [Int]$BenchmarkInterval = 60, #seconds per loop that MPM will have to collect hashrates when benchmarking. Allowed values: 60 - 300
    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 30)]
    [Int]$MinHashRateSamples = 10, #minumum number of hashrate samples that MPM will collect in benchmark operation (higher numbers produce more exact numbers, but will prolongue benchmarking. Allowed values: 10 - 30
    [Parameter(Mandatory = $false)]
    [ValidateRange(0.0, 1.0)]
    [Double]$PricePenaltyFactor = 1, #Estimated profit as projected by pool will be multiplied by this facator. Allowed values: 0.0 - 1.0
    [Parameter(Mandatory = $false)]
    [Switch]$MeasurePowerUsage = $false, #if true MPM will gather power usage per device and calculate power costs
    [Parameter(Mandatory = $false)]
    [Hashtable]$PowerPrices = @{ }, #Power price per KW, set value for each time frame, e.g. "00:00"=0.3;"06:30"=0.6;"18:30"=0.3, 24hr format!
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPowerUsage = $false, #Show power usage in miner overview list
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 999)]
    [Float]$BasePowerUsage = 0, #Additional base power usage (in Watt) for running the computer, monitor etc. regardless of mining hardware. Allowed values: 0.0 - 999
    [Parameter(Mandatory = $false)]
    [Switch]$IgnorePowerCost = $false, #if true MPM will ignore the calculated power costs when calculating profit
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 999)]
    [Float]$ProfitabilityThreshold = 0, #Minimum profit (in $Currency[0]) that must be made otherwise all mining will stop, set to 0 to allow mining even when making losses. Allowed values: 0.0 - 999
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 60)]
    [Int]$WarmupTime = 30, #Time the miner are allowed to warm up, e.g. to compile the binaries or to get the APi reads before it get marked as failed. Default 30 (seconds).
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$HWiNFO64_SensorMapping, #custom HWiNFO64 sensor mapping, only required when $MeasurePowerUsage is $true, see ConfigHWinfo64.pdf
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$MinWorker = [PSCustomObject]@{"*" = 10 }, #One entry per Algorithm name (wildcards like * and ? are supported) and workers that must be available for the algorithm, low number of workers is similar to solo mining :-(. Default for all algorithms is 10. Note: Wildcards (* and ?) for the algorithm names are supported. If an algorithm name/wildcard matches more than one entry then the lower number takes priority.
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [Float]$AllowedBadShareRatio = 0, #Allowed ratio of bad shares (total / bad) as reported by the miner. If the ratio exceeds the configured threshold then the miner will marked as failed. Allowed values: 0.00 - 1.00. Default of 0 disables this check
    [Parameter(Mandatory = $false)]
    [Int]$APIPort = 3999, #Port for the MPM API. The miner port range will start from $APIPort +1. Default: 3999, 
    [Parameter(Mandatory = $false)]
    [Switch]$ShowAllPoolBalances, #Include this command to display the balances of all pools (including those that are excluded with '-ExcludePoolName') on the summary screen and in the web dashboard.
    [Parameter(Mandatory = $false)]
    [Switch]$Dashboard = $false, #If true launch dashboard
    [Parameter(Mandatory = $false)]
    [Switch]$DisableMinersWithDevFee = $false, #Use only miners that do not have a dev fee built in
    [Parameter(Mandatory = $false)]
    [Switch]$DisableDevFeeMining = $false, #Set to true to disable miner fees (Note: not all miners support turning off their built in fees, others will reduce the hashrate)
    [Parameter(Mandatory = $false)]
    [Switch]$DisableEstimateCorrection = $false, #If true MPM will reduce the algo price by a correction factor (actual_last24h / estimate_last24h) to counter pool overestimated prices
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$IntervalMultiplier = [PSCustomObject]@{"EquihashR15053" = 2; "Mtp" = 2; "MtpNicehash" = 2; "ProgPow" = 2; "Rfv2" = 2; "X16r" = 5; "X16Rt" = 3; "X16RtGin" = 3; "X16RtVeil" = 3 } #IntervalMultiplier per Algo, if algo is not listed the default of 1 is used
)

Clear-Host

$Version = "3.5.2"
$VersionCompatibility = "3.3.0"
$Strikes = 3
$SyncWindow = 5 #minutes
$ProgressPreference = "silentlyContinue"

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Import-Module NetSecurity -ErrorAction Ignore
Import-Module Defender -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore
try { 
    Import-Module ThreadJob -ErrorAction Stop
    Set-Alias Start-Job Start-ThreadJob
}
catch { 
    Write-Log "Failed to import module (ThreadJob) - using normal 'Start-Job' instead. "
}

$Algorithm = [String[]]@($Algorithm | ForEach-Object { @(@(Get-Algorithm ($_ -split '-' | Select-Object -First 1) | Select-Object) + @($_ -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-' } | Select-Object)
$ExcludeAlgorithm = [String[]]@($ExcludeAlgorithm | ForEach-Object { @(@(Get-Algorithm ($_ -split '-' | Select-Object -First 1) | Select-Object) + @($_ -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-' } | Select-Object)
$Region = [String]@($Region | ForEach-Object { Get-Region $_ } | Select-Object -First 1)
$Currency = [String[]]@($Currency | ForEach-Object { $_.ToUpper() } | Select-Object)

$Timer = (Get-Date).ToUniversalTime()
$StatEnd = $Timer
$DecayStart = $Timer
$DecayPeriod = 60 #seconds
$DecayBase = 1 - 0.1 #decimal percentage
<#legacy#>$Intervals = @()

$WatchdogTimers = @()

[Miner[]]$ActiveMiners = @()
<#legacy#>$RunningMiners = @()
<#legacy#>$AllMinerPaths = @()

<#legacy#>$NewPools_JobsDurations = @()

#Start the log
Start-Transcript ".\Logs\MultiPoolMiner_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

Write-Log "Starting MultiPoolMiner® v$Version © 2017-$((Get-Date).Year) MultiPoolMiner.io"

#Unblock files
if (Get-Command "Unblock-File" -ErrorAction Ignore) { Get-ChildItem . -Recurse | Unblock-File }
if ((Get-Command "Get-MpPreference" -ErrorAction Ignore) -and (Get-MpComputerStatus -ErrorAction Ignore) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) { 
    Start-Process (@{desktop = "powershell"; core = "pwsh" }.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

#Initialize the API
if (Test-Path .\API.psm1 -PathType Leaf -ErrorAction Ignore) { Import-Module .\API.psm1 }

#Initialize config file
if (-not [IO.Path]::GetExtension($ConfigFile)) { $ConfigFile = "$($ConfigFile).txt" }
$Config_Temp = [PSCustomObject]@{ }
[Hashtable]$Config_Parameters = @{ }
$MyInvocation.MyCommand.Parameters.Keys | Sort-Object | ForEach-Object { 
    $Config_Parameters.$_ = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
    if ($Config_Parameters.$_ -is [Switch]) { $Config_Parameters.$_ = [Boolean]$Config_Parameters.$_ }
    $Config_Temp | Add-Member @{$_ = "`$$_" }
}
$Config_Temp | Add-Member @{Pools = @{ } } -Force
$Config_Temp | Add-Member @{MinersLegacy = @{ } } -Force
$Config_Temp | Add-Member @{Wallets = @{BTC = "`$Wallet" } } -Force
$Config_Temp | Add-Member @{VersionCompatibility = $VersionCompatibility } -Force
if (-not (Test-Path $ConfigFile -PathType Leaf -ErrorAction Ignore)) { 
    Write-Log -Level Info -Message "No valid config file found. Creating new config file ($ConfigFile) using defaults. "
    $Config_Temp | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile
}
Remove-Variable Config_Temp
$Config = [PSCustomObject]@{ }

#Set donation parameters
$LastDonated = $Timer.AddDays(-1).AddHours(1)
$WalletDonate = ((@("1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb") * 3) + (@("16Qf1mEk5x2WjJ1HhfnvPnqQEi2fvCeity") * 2) + (@("1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF") * 2))[(Get-Random -Minimum 0 -Maximum ((3 + 2 + 2) - 1))]
$UserNameDonate = ((@("aaronsace") * 3) + (@("grantemsley") * 2) + (@("uselessguru") * 2))[(Get-Random -Minimum 0 -Maximum ((3 + 2 + 2) - 1))]
$WorkerNameDonate = "multipoolminer_donate_$Version" -replace '[\W]', '-'

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

#HWiNFO64 ready? If HWiNFO64 is running it will recreate the reg key automatically
if (Test-Path "HKCU:\Software\HWiNFO64\VSB") { Remove-Item -Path "HKCU:\Software\HWiNFO64\VSB" -Recurse -ErrorAction SilentlyContinue }

if (Test-Path "APIs" -PathType Container -ErrorAction Ignore) { Get-ChildItem "APIs" -File | ForEach-Object { . $_.FullName } }

while (-not $API.Stop) { 
    #Display downloader progress
    if ($Downloader) { $Downloader | Receive-Job }

    #Load the configuration
    $OldConfig = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $Config = Get-ChildItemContent $ConfigFile -Parameters $Config_Parameters | Select-Object -ExpandProperty Content
    if ($Config -isnot [PSCustomObject]) { 
        Write-Log -Level Warn "Config file ($ConfigFile) is corrupt. "
        $Config = [PSCustomObject]@{ }
    }
    if ($Config.VersionCompatibility -and $VersionCompatibility -and [System.Version]$Config.VersionCompatibility -lt [System.Version]$VersionCompatibility) { 
        Write-Log -Level Warn "Config file ($ConfigFile [Version $($Config.VersionCompatibility)]) is not a valid configuration file (min. required config file version is $VersionCompatibility). "
    }

    #Repair the configuration
    $Config | Add-Member $Config_Parameters -ErrorAction Ignore
    $Config | Add-Member Wallets ([PSCustomObject]@{ }) -ErrorAction Ignore
    if ($Wallet -and -not $Config.Wallets.BTC) { $Config.Wallets | Add-Member BTC $Config.Wallet -ErrorAction Ignore }
    if (-not $Config.MinerStatusKey -and $Config.Wallets.BTC) { $Config | Add-Member MinerStatusKey $Config.Wallets.BTC -Force } #for backward compatibility
    $Config | Add-Member Pools ([PSCustomObject]@{ }) -ErrorAction Ignore
    @(Get-ChildItem "Pools" -File -ErrorAction Ignore) + @(Get-ChildItem "Balances" -File -ErrorAction Ignore) | Select-Object -ExpandProperty BaseName -Unique | ForEach-Object { 
        $Config.Pools | Add-Member $_ ([PSCustomObject]@{ }) -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member User $Config.UserName -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member Worker $Config.WorkerName -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member Wallets $Config.Wallets -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member API_ID $Config.API_ID -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member API_Key $Config.API_Key -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member PricePenaltyFactor $Config.PricePenaltyFactor -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member DisableEstimateCorrection $Config.DisableEstimateCorrection -ErrorAction Ignore
    }
    $Config | Add-Member Miners (Get-ChildItemContent "Miners") -ErrorAction Ignore
    $Config | Add-Member MinersLegacy ([PSCustomObject]@{ }) -ErrorAction Ignore
    Get-ChildItem "MinersLegacy" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | ForEach-Object { 
        $Config.MinersLegacy | Add-Member ($_ -split '-' | Select-Object -Index 0) ([PSCustomObject]@{ }) -ErrorAction Ignore
    }
    $BackupConfig = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json

    #Apply the configuration
    $FirstCurrency = $($Config.Currency | Select-Object -Index 0)
    if ($Config.Proxy) { $PSDefaultParameterValues["*:Proxy"] = $Config.Proxy }
    else { $PSDefaultParameterValues.Remove("*:Proxy") }
    #Needs clean-up
    if ($API.Port -and $Config.APIPort -ne $API.Port) { 
        #API port has changed, stop API and miners
        Write-Log -Level Info "Port for web dashboard and API has changed ($($API.Port) -> $($Config.APIPort)). $(if ($ActiveMiners | Where-Object Best) {'Stopping all runnig miners. '})"
        $RunningMiners | ForEach-Object { 
            $Miner = $_
            Write-Log "Stopping miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Pools.$_.Name)"}) -join "; ")}). "
            $Miner.SetStatus("Idle")
            $Miner.StatusMessage = " stopped gracefully (initiated by API port change)"
            $RunningMiners = @($RunningMiners | Where-Object { $_ -ne $Miner })
        }
        Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object { $AllMinerPaths -contains $_.ExecutablePath } | Select-Object -ExpandProperty ProcessID | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction Ignore }
        try { 
            Invoke-WebRequest -Uri "http://localhost:$($API.Port)/stopapi" -Timeout 1 -ErrorAction SilentlyContinue | Out-Null
        }
        catch { }
        Remove-Variable API -ErrorAction SilentlyContinue
        $ReportStatusJob | Select-Object | Remove-Job -Force
        $ReportStatusJob = $null
    }
    #Needs clean-up
    if ($Config.APIPort) { 
        if (-not $API.Port) { 
            $TCPClient = New-Object System.Net.Sockets.TCPClient
            $AsyncResult = $TCPClient.BeginConnect("localhost", $Config.APIPort, $null, $null)
            if ($AsyncResult.AsyncWaitHandle.WaitOne(100)) { 
                Write-Log -Level Error "Error starting web dashboard and API on port $($Config.APIPort). Port is in use. "
                try { $Null = $TCPClient.EndConnect($AsyncResult) }
                catch { }
            }
            else { 
                #Start API server
                if ($API) { Remove-Variable API }
                Start-APIServer -Port $Config.APIPort
                if ($API.Port) { 
                    Write-Log -Level Info "Web dashboard and API (version $($API.APIVersion)) running on http://localhost:$($API.Port). "
                    if ($Config.Dashboard) { Start-Process "http://localhost:$($Config.APIPort)/" } # Start web dashboard
                }
                else { 
                    Write-Log -Level Error "Error starting web dashboard and API on port $($Config.APIPort). "
                    $API = @{ }
                }
            }
            Remove-Variable AsyncResult
            Remove-Variable TCPClient
        }
    }
    if ($API) { 
        $API.Version = [PSCustomObject]@{"Core" = $Version; "API" = $API.APIVersion } #Give API access to the current version
        $API.Config = $BackupConfig #Give API access to the current running configuration
    }
    if ($API.Port -and $Config.MinerStatusKey -and $Config.ReportStatusInterval -and (-not $ReportStatusJob)) { 
        $ReportStatusJob = Start-Job -Name "ReportStatus" -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList "http://localhost:$($API.Port)" -FilePath .\ReportStatus.ps1 #Start monitoring service (requires running API)
    }

    #Load unprofitable algorithms
    [String[]]$UnprofitableAlgorithms = @()
    if (Test-Path ".\UnprofitableAlgorithms.txt" -PathType Leaf -ErrorAction Ignore) { [String[]]$UnprofitableAlgorithms = @(Get-Content ".\UnprofitableAlgorithms.txt" | ConvertFrom-Json -ErrorAction SilentlyContinue | Sort-Object -Unique) }

    #Activate or deactivate donation
    if ($Config.Donate -lt 10) { $Config.Donate = 10 }
    if ($Timer.AddDays(-1).AddMinutes(-1).AddSeconds(1) -ge $LastDonated) { $LastDonated = $Timer }
    if ($Timer.AddDays(-1).AddMinutes($Config.Donate) -ge $LastDonated) { 
        if ($WalletDonate -and $UserNameDonate -and $WorkerNameDonate) { 
            Write-Log "Donation run, mining to donation address for the next $(($LastDonated - ($Timer.AddDays(-1))).Minutes +1) minutes. Note: MPM will use ALL available pools. "
            $Config | Add-Member Pools ([PSCustomObject]@{ }) -Force
            Get-ChildItem "Pools" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | ForEach-Object { 
                $Config.Pools | Add-Member $_ ([PSCustomObject]@{ 
                        User               = $UserNameDonate
                        Worker             = $WorkerNameDonate
                        Wallets            = [PSCustomObject]@{BTC = $WalletDonate }
                        PricePenaltyFactor = 1
                    }) -Force
            }
            $Config | Add-Member PoolName (@()) -Force
            $Config | Add-Member ExcludePoolName (@()) -Force
        }
        else { 
            Write-Log -Level Warn "Donation information is missing. "
        }
    }
    else { 
        Write-Log ("Mining for you. Donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($LastDonated.AddDays(1) - ($Timer.AddMinutes($Config.Donate))))
    }

    #Check if the configuration has changed
    if (($OldConfig | ConvertTo-Json -Compress -Depth 10) -ne ($Config | ConvertTo-Json -Compress -Depth 10)) { 
        $AllPools | Select-Object | ForEach-Object { $_.Price = 0 }
        $AllDevices = @(Get-Device -DevicePciOrderMapping $Config.DevicePciOrderMapping -Refresh | Select-Object)
        if ($API) { $API.AllDevices = $AllDevices } #Give API access to the device information
    }

    #Load information about the devices
    $Devices = @(Get-Device -DevicePciOrderMapping $Config.DevicePciOrderMapping -Name @($Config.DeviceName | Select-Object) -ExcludeName @($Config.ExcludeDeviceName | Select-Object) | Select-Object)
    if ($API) { $API.Devices = $Devices } #Give API access to the device information
    if ($API) { Update-APIDeviceStatus $API $Devices } #To be removed
    if ($Devices.Count -eq 0) { 
        Write-Log -Level Warn "No mining devices found. "
        while ((Get-Date).ToUniversalTime() -lt $StatEnd) { Start-Sleep 10 }
        continue
    }

    #Set master timer
    $Timer = (Get-Date).ToUniversalTime()
    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Config.Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd
    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)
    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

    #Give API access to the timer information
    if ($API) { 
        $API.Timer = $Timer
        $API.StatStart = $StatStart
        $API.StatEnd = $StatEnd
        $API.StatSpan = $StatSpan
        $API.DecayExponent = $DecayExponent
        $API.WatchdogInterval = $WatchdogInterval
        $API.WatchdogReset = $WatchdogReset
    }

    #Load information about the pools
    if ((Test-Path "Pools" -PathType Container -ErrorAction Ignore) -and (-not $NewPools_Jobs)) { 
        if ($PoolsRequest = @(Get-ChildItem "Pools" -File | Where-Object { $Config.Pools.$($_.BaseName) -and $Config.ExcludePoolName -inotcontains $_.BaseName } | Where-Object { $Config.PoolName.Count -eq 0 -or $Config.PoolName -contains $_.BaseName } | Sort-Object BaseName)) { 
            $Config | Add-Member "PoolList" @($PoolsRequest.BaseName) -Force
            Write-Log "Loading pool information ($($Config.PoolList -join '; ')) - this may take a minute or two. "
            $NewPools_Jobs = @(
                $PoolsRequest | ForEach-Object { 
                    $Pool_Name = $_.BaseName
                    $Pool_Parameters = @{StatSpan = $StatSpan; Config = $Config; JobName = "Pool_$($_.BaseName)" }
                    $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object { $Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name) }
                    Get-ChildItemContent "Pools\$($_.Name)" -Parameters $Pool_Parameters -Threaded
                } | Select-Object
            )
            if ($API) { $API.NewPools_Jobs = $NewPools_Jobs } #Give API access to pool jobs information
        }
        else { 
            Write-Log -Level Warn "No pools available. "
            while ((Get-Date).ToUniversalTime() -lt $StatEnd) { Start-Sleep 10 }
            continue
        }
        Remove-Variable PoolsRequest
    }


    #Power cost preparations
    $PowerPrice = [Double]0
    $PowerCostBTCperW = [Double]0
    $BasePowerCost = [Double]0
    if ($Devices.Count -and $Config.MeasurePowerUsage) { 
        #HWiNFO64 verification
        $RegKey = "HKCU:\Software\HWiNFO64\VSB"
        $OldRegistryValue = $RegistryValue
        if ($RegistryValue = Get-ItemProperty -Path $RegKey -ErrorAction SilentlyContinue) { 
            if ([String]$OldRegistryValue -eq [String]$RegistryValue) { 
                Write-Log -Level Warn "Power usage info in registry has not been updated [HWiNFO64 not running???] - power cost calculation is not available. "
                $Config.MeasurePowerUsage = $false
            }
            else { 
                $Hashtable = @{ }
                $Device = ""
                $RegistryValue.PsObject.Properties | Where-Object { $_.Name -match "^Label[0-9]+$" -and (Compare-Object @($_.Value -split ' ' | Select-Object) @($Devices.Name | Select-Object) -IncludeEqual -ExcludeDifferent) } | ForEach-Object { 
                    $Device = ($_.Value -split ' ') | Select-Object -last 1
                    try { 
                        $Hashtable.Add($Device, $RegistryValue.($_.Name -replace "Label", "Value"))
                    }
                    catch { 
                        Write-Log -Level Warn "HWiNFO64 sensor naming is invalid [duplicate sensor for $Device] - disabling power usage calculations. "
                        $Config.MeasurePowerUsage = $false
                    }
                }
                if ($Devices.Name | Where-Object { $Hashtable.$_ -eq $null }) { 
                    Write-Log -Level Warn "HWiNFO64 sensor naming is invalid [missing sensor for $(($Devices.Name | Where-Object {$Hashtable.$_ -eq $null}) -join ', ')] - disabling power usage calculations. "
                    $Config.MeasurePowerUsage = $false
                }
                Remove-Variable Device
                Remove-Variable HashTable
            }
        }
        else { 
            Write-Log -Level Warn "Cannot read power usage info from registry [Key '$($RegKey)' does not exist - HWiNFO64 not running???] - power cost calculation is not available. "
            $Config.MeasurePowerUsage = $false
        }
        Remove-Variable RegistryValue
        Remove-Variable RegKey
    }

    #Retrieve collected pool data
    $NewPools = @()
    if ($NewPools_Jobs) { 
        if ($NewPools_Jobs | Where-Object State -NE "Completed") { Write-Log "Waiting for pool information. " }
        $NewPools = @($NewPools_Jobs | Receive-Job -Wait -AutoRemoveJob -ErrorAction SilentlyContinue | ForEach-Object { $_.Content | Add-Member Name $_.Name -Force -PassThru })
        $NewPools_JobsDurations = @($NewPools_JobsDurations | Select-Object -Last 20) #Use the last 20 values for better stability
        $NewPools_JobsDurations += (($NewPools_Jobs | Measure-Object PSEndTime -Maximum).Maximum - ($NewPools_Jobs | Measure-Object PSBeginTime -Minimum).Minimum).TotalSeconds
        Remove-Variable NewPools_Jobs
        if ($API) { $API.NewPools_Jobs = $null }
    }

    #Update the pool balances every n minute to minimize web requests or when currency or pool settings have changed; pools usually do not update the balances in real time
    if (Test-Path "Balances" -PathType Container -ErrorAction Ignore) { 
        if ($BalancesRequest = @(Get-ChildItem "Balances" -File | Where-Object { $Config.ShowAllPoolBalances -or ($BackupConfig.Pools.$($_.BaseName) -and @($BackupConfig.ExcludePoolName -replace "Coins") -inotcontains $_.BaseName) } | Where-Object { $Config.ShowAllPoolBalances -or ($BackupConfig.PoolName.Count -eq 0 -or @($BackupConfig.PoolName -replace "Coins") -contains $_.BaseName) } | Where-Object { $PoolName = $_.BaseName; ($Balances | Where-Object { $_.Pool -eq $PoolName } | Sort-Object Pool -Unique | Sort-Object "LastUpdated").LastUpdated -lt (Get-Date).ToUniversalTime().AddMinutes(-$Config.PoolBalancesUpdateInterval) })) { 
            Write-Log "Loading balances information ($($BalancesRequest.BaseName -join '; ')). "
            $Balances_Jobs = @(
                $BalancesRequest | ForEach-Object { 
                    $Balances_Name = $_.BaseName
                    $Balances_Parameters = @{JobName = "Balance_$($Balances_Name)" }
                    $BackupConfig.Pools.$Balances_Name | Get-Member -MemberType NoteProperty | ForEach-Object { $Balances_Parameters.($_.Name) = $BackupConfig.Pools.$Balances_Name.($_.Name) } # Use BackupConfig to not query donation balances
                    Get-ChildItemContent "Balances\$($_.Name)" -Parameters $Balances_Parameters -Threaded
                } | Select-Object
            )
            if ($API) { $API.Balances_Jobs = $Balances_Jobs } #Give API access to balances jobs information
            Remove-Variable BalancesRequest
        }
    }

    #TempFix: Gin and Veil are separate implementations of the same algorithm which are not compatible with all miners
    $NewPools | Where-Object Algorithm -EQ "X16rt" | Where-Object CoinName -match "GinCoin|Veil" | ForEach-Object { 
        $Pool = $_ | ConvertTo-Json | ConvertFrom-Json
        Switch ($_.CoinName) { 
            "GinCoin" { $Pool.Algorithm = "X16RtGin"; if (-not ($NewPools | Where-Object { $_.Name -EQ $Pool.Name -and $_.Algorithm -EQ $Pool.Algorithm })) { $NewPools += $Pool } }
            "Veil" { $Pool.Algorithm = "X16RtVeil"; if (-not ($NewPools | Where-Object { $_.Name -EQ $Pool.Name -and $_.Algorithm -EQ $Pool.Algorithm })) { $NewPools += $Pool } }
        }
        Remove-Variable Pool
    }

    #Apply PricePenaltyFactor to pools
    $NewPools | ForEach-Object { 
        $_.Price = [Double]($_.Price * $Config.Pools.$($_.Name).PricePenaltyFactor)
        $_.StablePrice = [Double]($_.StablePrice * $Config.Pools.$($_.Name).PricePenaltyFactor)
    }
    if ($API) { $API.NewPools = $NewPools } #Give API access to the current running configuration
    #This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    if (($Config | ConvertTo-Json -Compress -Depth 10) -ne ($OldConfig | ConvertTo-Json -Compress -Depth 10)) { $AllPools = $null }
    $OldestAcceptedPoolData = (Get-Date).ToUniversalTime().AddHours( -24) # Allow only pools which were updated within the last 24hrs


    $AllPools = @(@($NewPools) + @(Compare-Object @($NewPools | Select-Object -ExpandProperty Name -Unique) @($AllPools | Select-Object -ExpandProperty Name -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object { $AllPools | Where-Object Name -EQ $_ }) | 
        Where-Object { $_.MarginOfError -le (1 - $Config.MinAccuracy) } | 
        Where-Object { $_.Updated -ge $OldestAcceptedPoolData } | 
        Where-Object { -not $Config.PoolName -or (Compare-Object @($Config.PoolName | Select-Object) @($(for ($i = ($_.Name -split "-").length; $i -ge 1; $i--) { ($_.Name -split "-" | select-object -first $i) -join "-" }) | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.ExcludePoolName -or -not (Compare-Object @($Config.ExcludePoolName | Select-Object) @($(for ($i = ($_.Name -split "-").length; $i -ge 1; $i--) { ($_.Name -split "-" | select-object -first $i) -join "-" }) | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.Algorithm -or (Compare-Object @($Config.Algorithm | Select-Object) @($(for ($i = ($_.Algorithm -split "-").length; $i -ge 1; $i--) { ($_.Algorithm -split "-" | select-object -first $i) -join "-" }) | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.ExcludeAlgorithm -or -not (Compare-Object @($Config.ExcludeAlgorithm | Select-Object) @($(for ($i = ($_.Algorithm -split "-").length; $i -ge 1; $i--) { ($_.Algorithm -split "-" | select-object -first $i) -join "-" }) | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.Pools.$($_.Name).ExcludeAlgorithm -or (Compare-Object @($Config.Pools.$($_.Name).ExcludeAlgorithm | Select-Object) @($_.Algorithm, ($_.Algorithm -split "-" | Select-Object -Index 0) | Select-Object -Unique)  -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } | 
        Where-Object { -not $Config.Pools.$($_.Name).Region -or (Compare-Object @($Config.Pools.$($_.Name).Region | Select-Object) @($_.Region) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.Pools.$($_.Name).ExcludeRegion -or -not (Compare-Object @($Config.Pools.$($_.Name).ExcludeRegion | Select-Object) @($_.Region) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.CoinName -or (Compare-Object @($Config.CoinName | Select-Object) @($_.CoinName | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.Pools.$($_.Name).CoinName -or (Compare-Object @($Config.Pools.$($_.Name).CoinName | Select-Object) @($_.CoinName | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.ExcludeCoinName -or -not (Compare-Object @($Config.ExcludeCoinName | Select-Object) @($_.CoinName | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.Pools.$($_.Name).ExcludeCoinName -or -not (Compare-Object @($Config.Pools.$($_.Name).ExcludeCoinName | Select-Object) @($_.CoinName | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.MiningCurrency -or (Compare-Object @($Config.MiningCurrency | Select-Object) @($_.MiningCurrency | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.Pools.$($_.Name).MiningCurrency -or (Compare-Object @($Config.Pools.$($_.Name).MiningCurrency | Select-Object) @($_.MiningCurrency | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.ExcludeMiningCurrency -or -not (Compare-Object @($Config.ExcludeMiningCurrency | Select-Object) @($_.MiningCurrency | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { -not $Config.Pools.$($_.Name).ExcludeMiningCurrency -or -not (Compare-Object @($Config.Pools.$($_.Name).ExcludeMiningCurrency | Select-Object) @($_.MiningCurrency | Select-Object) -IncludeEqual -ExcludeDifferent) } | 
        Where-Object { $Algorithm = $_.Algorithm -replace "NiceHash"<#temp fix#>; $_.Workers -eq $null -or $_.Workers -ge (($Config.MinWorker.PSObject.Properties.Name | Where-Object { $Algorithm -like $_ } | ForEach-Object { $Config.MinWorker.$_ }) | Measure-Object -Minimum).Minimum } | 
        Where-Object { $PoolName = $_.Name; $_.Workers -eq $null -or $_.Workers -ge (($Config.Pools.$($PoolName).MinWorker.PSObject.Properties.Name | Where-Object { $Algorithm -like $_ } | ForEach-Object { $Config.Pools.$($PoolName).MinWorker.$_ }) | Measure-Object -Minimum).Minimum } | 
        ForEach-Object { if ($_.EstimateCorrection -le 0) { $_ | Add-Member EstimateCorrection 1 -Force }; $_ } | 
        ForEach-Object { if ((-not $Config.Pools.$Name.DisableEstimateCorrection) -and $_.EstimateCorrection -ge 0 -and $_.EstimateCorrection -lt 1) { $_.Price = $_.Price * $_.EstimateCorrection; $_.StablePrice = $_.StablePrice * $_.EstimateCorrection }; $_ } | 
        Sort-Object Algorithm)

    Remove-Variable NewPools

    if ($API) { $API.AllPools = $AllPools } #Give API access to the current running configuration

    if ($AllPools.Count -eq 0) { 
        Write-Log -Level Warn "No pools available. "
        while ((Get-Date).ToUniversalTime() -lt $StatEnd) { Start-Sleep 10 }
        continue
    }
    #Apply watchdog to pools
    $AllPools = @(
        $AllPools | Where-Object { 
            $Pool = $_
            $Pool_WatchdogTimers = @($WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset))
            ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object { $Pool.Algorithm -contains $_.Algorithm } | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
        }
    )

    #Update the active pools
    Write-Log "Selecting best pool for each algorithm. "
    $Pools = [PSCustomObject]@{ }
    $AllPools.Algorithm | ForEach-Object { $_.ToLower() } | Select-Object -Unique | ForEach-Object { $Pools | Add-Member $_ ($AllPools | Where-Object Algorithm -EQ $_ | Sort-Object -Descending { $Config.PoolName.Count -eq 0 -or (Compare-Object $Config.PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0 }, { ($Timer - $_.Updated).TotalMinutes -le ($SyncWindow * $Strikes) }, { $_.StablePrice * (1 - $_.MarginOfError) }, { $_.Region -EQ $Config.Region }, { $_.SSL -EQ $Config.SSL } | Select-Object -First 1) }
    if (($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Pools.$_.Name } | Select-Object -Unique | ForEach-Object { $AllPools | Where-Object Name -EQ $_ | Measure-Object Updated -Maximum | Select-Object -ExpandProperty Maximum } | Measure-Object -Minimum -Maximum | ForEach-Object { $_.Maximum - $_.Minimum } | Select-Object -ExpandProperty TotalMinutes) -gt $SyncWindow) { 
        Write-Log -Level Warn "Pool prices are out of sync ($([Int]($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_} | Measure-Object Updated -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes)) minutes). "
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Pools.$_ | Add-Member Price_Bias ($Pools.$_.StablePrice * (1 - ($Pools.$_.MarginOfError * $(if ($Pools.$_.PayoutScheme -eq "PPLNS") { $Config.SwitchingPrevention } else { 1 }) * (1 - $Pools.$_.Fee) * [Math]::Pow($DecayBase, $DecayExponent)))) -Force }
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Pools.$_ | Add-Member Price_Unbias ($Pools.$_.StablePrice * (1 - $Pools.$_.Fee)) -Force }
    }
    else { 
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Pools.$_ | Add-Member Price_Bias ($Pools.$_.Price * (1 - ($Pools.$_.MarginOfError * $(if ($Pools.$_.PayoutScheme -eq "PPLNS") { $Config.SwitchingPrevention } else { 1 }) * (1 - $Pools.$_.Fee) * [Math]::Pow($DecayBase, $DecayExponent)))) -Force }
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object { $Pools.$_ | Add-Member Price_Unbias ($Pools.$_.Price * (1 - $Pools.$_.Fee)) -Force }
    }
    if ($API) { $API.Pools = $Pools } #Give API access to the pools information

    #Load the stats, to improve performance only read PowerUsage stats when required
    Write-Log "Loading saved statistics. "
    if ($API) { $API.Stats = Get-Stat } #Give API access to the current stats

    #Load information about the miners
    #Messy...?
    Write-Log "Getting miner information. "
    # Get all the miners, get just the .Content property and add the name, select only the ones that match our $Config.DeviceName (CPU, AMD, NVIDIA) or all of them if type is unset, 
    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Config.MinerName, if specified, and don't match $Config.ExcludeMinerName
    $AllMiners = @(
        if (Test-Path "MinersLegacy" -PathType Container -ErrorAction Ignore) { 
            #Strip Model information from devices -> will create only one miner instance
            if ($Config.DisableDeviceDetection) { $DevicesTmp = $Devices | ConvertTo-Json -Depth 10 | ConvertFrom-Json; $DevicesTmp | ForEach-Object { $_.Model = "" } } else { $DevicesTmp = $Devices }
            Get-ChildItemContent "MinersLegacy" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config; Devices = $DevicesTmp; JobName = "MinersLegacy" } | ForEach-Object { 
                $_.Content | Add-Member Name $_.Name -PassThru -Force; $_.Content.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_.Content.Path); $AllMinerPaths += $_.Content.Path } | 
            Where-Object { $UnprofitableAlgorithms -notcontains (($_.HashRates.PSObject.Properties.Name | Select-Object -Index 0) -replace 'NiceHash'<#temp fix#>) } | #filter unprofitable algorithms, allow them as secondary algo
            Where-Object { $_.HashRates.PSObject.Properties.Value -notcontains 0 } | #filter miner with 0 hashrate
            Where-Object { $_.HashRates.PSObject.Properties.Value -notcontains -1 } | #filter diabled miner (-1 hashrate)
            Where-Object { -not $Config.SingleAlgoMining -or @($_.HashRates.PSObject.Properties.Name).Count -EQ 1 } | #filter dual algo miners
            Where-Object { $Config.MinerName.Count -eq 0 -or (Compare-Object @($Config.MinerName | Select-Object) @($_.BaseName, "$($_.BaseName)_$($_.Version)", $_.Name | Select-Object -Unique) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0 } | 
            Where-Object { $Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object @($Config.ExcludeMinerName | Select-Object) @($_.BaseName, "$($_.BaseName)_$($_.Version)", $_.Name | Select-Object -Unique) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } |
            Where-Object { -not ($Config.DisableMinersWithDevFee -and $_.Fees) } |
            Where-Object { $Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName).$($_.Version).ExcludeAlgorithm | Select-Object) @($_.HashRates.PSObject.Properties.Name -replace 'NiceHash'<#temp fix#> | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } | 
            Where-Object { $Config.MinersLegacy.$($_.BaseName)."*".ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.MinersLegacy.$($_.BaseName)."*".ExcludeAlgorithm | Select-Object) @($_.HashRates.PSObject.Properties.Name -replace 'NiceHash'<#temp fix#> | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0 } | 
            ForEach-Object { if (-not $_.ShowMinerWindow) { $_ | Add-Member ShowMinerWindow $Config.ShowMinerWindow -Force }; $_ } | #default ShowMinerWindow 
            ForEach-Object { $_ | Add-Member IntervalMultiplier (@(@($_.HashRates.PSObject.Properties.Name | ForEach-Object { $Config.IntervalMultiplier.$_ } | Select-Object) + 1 + $($_.IntervalMultiplier)) | Measure-Object -Maximum).Maximum -Force; $_ } | #default interval multiplier is 1
            ForEach-Object { if (-not $_.WarmupTime) { $_ | Add-Member WarmupTime $Config.WarmupTime -Force }; $_ } #default WarmupTime is taken from config file
        }
    )
    if ($API) { $API.AllMiners = $AllMiners } #Give API access to the AllMiners information
    $AllMinerPaths = $AllMinerPaths | Sort-Object -Unique

    #Retrieve collected balance data
    if ($Balances_Jobs) { 
        $Balances = @(($Balances + @($Balances_Jobs | Receive-Job -Wait -AutoRemoveJob -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Content | Sort-Object Name)) | Sort-Object LastUpdated | Sort-Object "Name" -Unique | Where-Object Total -GT 0)
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
        $PowerCostBTCperW = [Double](1 / 1000 * 24 * $PowerPrice / $Rates.BTC.$FirstCurrency)
        $BasePowerCost = [Double]($Config.BasePowerUsage / 1000 * 24 * $PowerPrice / $Rates.BTC.$FirstCurrency)
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
            $Miner_Earnings_MarginOfError | Add-Member $_ ([Double]$Pools.$_.MarginOfError * $Pools.$_.EstimateCorrection * (& { if ($Miner_Earning) { ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice) / $Miner_Earning } else { 1 } }))
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
    $MinersNeedingPowerUsageMeasurement = @($(if ($Config.MeasurePowerUsage) { @($Miners | Where-Object PowerUsage -EQ $null | Where-Object { $_.HashRates.PSObject.Properties.Value -notcontains 0 }) }))
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
            $_.Arguments -eq $Miner.Arguments -and 
            $_.API -eq $Miner.API -and 
            $_.Port -eq $Miner.Port -and 
            $_.ShowMinerWindow -eq $Miner.ShowMinerWindow -and 
            $_.AllowedBadShareRatio -eq $Miner.AllowedBadShareRatio -and
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }
        if ($ActiveMiner) { 
            $ActiveMiner.DeviceName = $Miner.DeviceName
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
                PoolName              = [Array]$Miner.Pools.PSObject.Properties.Value.Name #temp fix, must use 'PSObject.Properties' to preserve order
                ShowMinerWindow       = $Miner.ShowMinerWindow
                IntervalMultiplier    = $Miner.IntervalMultiplier
                Environment           = $Miner.Environment
                DeviceId              = [Array]($Miner | ForEach-Object { (Get-Device $_.DeviceName).Type_Vendor_Index }) #Add DeviceID, required for power readouts
                PowerCost             = $Miner.PowerCost
                PowerUsage            = $Miner.PowerUsage
                WarmupTime            = $Miner.WarmupTime
                AllowedBadShareRatio  = $Miner.AllowedBadShareRatio
            }
        }
    }

    #Check for failed miner
    $RunningMiners | Where-Object { $_.GetStatus() -ne "Running" } | ForEach-Object { 
        $_.StatusMessage = " exited unexpectedly"
        $_.SetStatus("Failed")
        Write-Log -Level Error "Miner ($($_.Name) {$(($_.Algorithm | ForEach-Object {"$($_)@$($Pools.$_.Name)"}) -join "; ")})$(if ($_.StatusMessage) {$_.StatusMessage} else {" has failed"}). "

        #Post miner failure exec
        $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $_ -Config $Config -Event "PostStop"))).Trim()
        if ($Command) { Start-PrePostCommand -Command $Command -Event "PostStop" }
        Remove-Variable Command
    }

    #Don't penalize active or benchmarking miners
    $ActiveMiners | Where-Object { $_.GetStatus() -EQ "Running" -or ($_.Intervals.Count -and $_.Speed -contains $null) } | ForEach-Object { $_.Earning_Bias = $_.Earning_Unbias; $_.Profit_Bias = $_.Profit_Unbias }

    #Update API miner information
    if ($API) { 
        $API.ActiveMiners = $ActiveMiners
        $API.RunningMiners = @($ActiveMiners | Where-Object { $_.GetStatus() -eq "Running" })
        $API.FailedMiners = @($ActiveMiners | Where-Object { $_.GetStatus() -eq "Failed" })
        Update-APIDeviceStatus $API $Devices
    }


    #Hack: temporarily make all earnings & profits positive, BestMiners_Combos(_Comparison) produces wrong sort order when earnings or profits are negative
    $SmallestEarningBias = ([Double][Math]::Abs(($ActiveMiners | Sort-Object Earning_Bias | Select-Object -First 1).Earning_Bias)) * 2
    $SmallestEarningComparison = ([Double][Math]::Abs(($ActiveMiners | Sort-Object Earning_Comparison | Select-Object -First 1).Earning_Comparison)) * 2
    $SmallestProfitBias = ([Double][Math]::Abs(($ActiveMiners | Sort-Object Profit_Bias | Select-Object -First 1).Profit_Bias)) * 2
    $SmallestProfitComparison = ([Double][Math]::Abs(($ActiveMiners | Sort-Object Profit_Comparison | Select-Object -First 1).Profit_Comparison)) * 2
    $ActiveMiners | ForEach-Object { $_.Earning_Bias += $SmallestEarningBias; $_.Earning_Comparison += $SmallestEarningComparison; $_.Profit_Bias += $SmallestProfitBias; $_.Profit_Comparison += $SmallestProfitComparison }

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    if ($Config.IgnorePowerCost) { 
        $BestMiners = @($ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object { $Miner_GPU = $_; ($ActiveMiners | Where-Object { (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Earning -ne 0 } | Sort-Object -Descending { ($_ | Where-Object Earning -EQ $null | Measure-Object).Count }, { $(if ($_.Earning -eq $null) { $_.IntervalMultiplier } else { 0 }) }, { $Config.MeasurePowerUsage -and $_.Earning -ne $null -and $_.PowerUsage -eq $null }, { $_.Earning_Bias }, { $_ | Where-Object Earning -NE 0 }, { $_.Intervals.Count } | Select-Object -First 1) })
        $BestMiners_Comparison = @($ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object { $Miner_GPU = $_; ($ActiveMiners | Where-Object { (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Earning -ne 0 } | Sort-Object -Descending { ($_ | Where-Object Earning -EQ $null | Measure-Object).Count }, { $(if ($_.Earning -eq $null) { $_.IntervalMultiplier } else { 0 }) }, { $Config.MeasurePowerUsage -and $_.Earning -ne $null -and $_.PowerUsage -eq $null }, { $_.Earning_Comparison }, { $_ | Where-Object Earning -NE 0 }, { $_.Intervals.Count } | Select-Object -First 1) })
    }
    else { 
        $BestMiners = @($ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object { $Miner_GPU = $_; ($ActiveMiners | Where-Object { (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Profit -ne 0 } | Sort-Object -Descending { ($_ | Where-Object Profit -EQ $null | Measure-Object).Count }, { $(if ($_.Profit -eq $null) { $_.IntervalMultiplier } else { 0 }) }, { $Config.MeasurePowerUsage -and $_.Profit -ne $null -and $_.PowerUsage -eq $null }, { $_.Profit_Bias }, { $_ | Where-Object Profit -NE 0 }, { $_.Intervals.Count } | Select-Object -First 1) })
        $BestMiners_Comparison = @($ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object { $Miner_GPU = $_; ($ActiveMiners | Where-Object { (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Profit -ne 0 } | Sort-Object -Descending { ($_ | Where-Object Profit -EQ $null | Measure-Object).Count }, { $(if ($_.Profit -eq $null) { $_.IntervalMultiplier } else { 0 }) }, { $Config.MeasurePowerUsage -and $_.Profit -ne $null -and $_.PowerUsage -eq $null }, { $_.Profit_Comparison }, { $_ | Where-Object Profit -NE 0 }, { $_.Intervals.Count } | Select-Object -First 1) })
    }
    $Miners_Device_Combos = @(Get-Combination ($ActiveMiners | Select-Object DeviceName -Unique) | Where-Object { (Compare-Object ($_.Combination | Select-Object -ExpandProperty DeviceName -Unique) ($_.Combination | Select-Object -ExpandProperty DeviceName) | Measure-Object).Count -eq 0 })
    $BestMiners_Combos = @(
        $Miners_Device_Combos | ForEach-Object { 
            $Miner_Device_Combo = $_.Combination
            [PSCustomObject]@{ 
                Combination = $Miner_Device_Combo | ForEach-Object { 
                    $Miner_Device_Count = $_.DeviceName.Count
                    [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object { [Regex]::Escape($_) }) -join '|') + ")$"
                    $BestMiners | Where-Object { ([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count }
                }
            }
        }
    )
    $BestMiners_Combos_Comparison = @(
        $Miners_Device_Combos | ForEach-Object { 
            $Miner_Device_Combo = $_.Combination
            [PSCustomObject]@{ 
                Combination = $Miner_Device_Combo | ForEach-Object { 
                    $Miner_Device_Count = $_.DeviceName.Count
                    [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object { [Regex]::Escape($_) }) -join '|') + ")$"
                    $BestMiners_Comparison | Where-Object { ([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count }
                }
            }
        }
    )
    $BestMiners_Combo = @($BestMiners_Combos | Sort-Object -Descending { ($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count }, { ($_.Combination | Measure-Object Profit_Bias -Sum).Sum }, { ($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count } | Select-Object -First 1 | Select-Object -ExpandProperty Combination)
    $BestMiners_Combo_Comparison = @($BestMiners_Combos_Comparison | Sort-Object -Descending { ($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count }, { ($_.Combination | Measure-Object Profit_Comparison -Sum).Sum }, { ($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count } | Select-Object -First 1 | Select-Object -ExpandProperty Combination)

    if ($ActiveMiners.Count -eq 1) { 
        $BestMiners_Combo_Comparison = $BestMiners_Combo = @($ActiveMiners)
    }

    #ProfitabilityThreshold check
    $MiningEarning = (($BestMiners_Combo | Measure-Object Earning -Sum).Sum) * $Rates.BTC.$FirstCurrency
    $MiningProfit = (($BestMiners_Combo | Measure-Object Profit -Sum).Sum) * $Rates.BTC.$FirstCurrency
    $MiningCost = (($BestMiners_Combo | Measure-Object PowerCost -Sum).Sum + $BasePowerCost) * $Rates.BTC.$FirstCurrency
    if ($API) { 
        $API.BestMiners = $BestMiners
        $API.BestMiners_Comparison = $BestMiners_Comparison
        $API.BestMiners_Combos = $BestMiners_Combos
        $API.BestMiners_Combos_Comparison = $BestMiners_Combos_Comparison
        $API.BestMiners_Combo = $BestMiners_Combo
        $API.BestMiners_Combo_Comparison = $BestMiners_Combo_Comparison
        $API.MiningEarning = $MiningEarning
        $API.MiningProfit = $MiningProfit
        $API.MiningCost = $MiningCost
    }

    #OK to run miners?
    if (($MiningEarning - $MiningCost) -ge $Config.ProfitabilityThreshold -or $MinersNeedingBenchmark.Count -gt 0 -or $MinersNeedingPowerUsageMeasurement.count -gt 0) { 
        $BestMiners_Combo | ForEach-Object { $_.Best = $true }
        $BestMiners_Combo_Comparison | ForEach-Object { $_.Best_Comparison = $true }
    }
    Remove-Variable BestMiners_Combo
    Remove-Variable BestMiners_Combo_Comparison
    Remove-Variable Miner_Device_Combo
    Remove-Variable Miners_Device_Combos
    Remove-Variable BestMiners
    Remove-Variable BestMiners_Comparison

    #Hack part 2: reverse temporarily forced positive earnings & profits
    $ActiveMiners | ForEach-Object { $_.Earning_Bias -= $SmallestEarningBias; $_.Earning_Comparison -= $SmallestEarningComparison; $_.Profit_Bias -= $SmallestProfitBias; $_.Profit_Comparison -= $SmallestProfitComparison }
    Remove-Variable SmallestEarningBias
    Remove-Variable SmallestEarningComparison
    Remove-Variable SmallestProfitBias
    Remove-Variable SmallestProfitComparison


    #Stop miners in the active list depending on if they are the most profitable
    $ActiveMiners | Where-Object { $_.GetActivateCount() } | Where-Object { $_.Best -EQ $false -or ($Config.ShowMinerWindow -ne $OldConfig.ShowMinerWindow) } | ForEach-Object { 
        $Miner = $_
        $RunningMiners = $RunningMiners | Where-Object $_ -NE $Miner
        if ($Miner.GetStatus() -eq "Running") { 
            #Pre miner start exec
            $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PreStop"))).Trim()
            if ($Command) { Start-PrePostCommand -Command $Command -Event "PreStop" }

            Write-Log "Stopping miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Miner.PoolName | Select-Object -Index ([array]::indexof($Miner.Algorithm, $_)))"}) -join "; ")}). "
            $Miner.SetStatus("Idle")
            $Miner.StatusMessage = " stopped gracefully"
            if ($Miner.ProcessId -and -not ($ActiveMiners | Where-Object { $_.Best -and $_.API -EQ $Miner.API })) { Stop-Process -Id $Miner.ProcessId -Force -ErrorAction Ignore } #temp fix
            #Post miner stop exec
            $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PostStop"))).Trim()
            if ($Command) { Start-PrePostCommand -Command $Command -Event "PostStop" }

            #Remove watchdog timer
            $Miner_IntervalMultiplier = $Miner.IntervalMultiplier
            $Miner.Algorithm | ForEach-Object { 
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object { $_.MinerName -eq $Miner.Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm }
                if ($WatchdogTimer) { 
                    if ($WatchdogTimer.Kicked -lt $Timer.AddSeconds( - $WatchdogInterval * $Miner_IntervalMultiplier)) { 
                        $Miner.SetStatus("Failed")
                        $Miner.StatusMessage = " was temporarily disabled by watchdog"
                        Write-Log -Level Warn "Watchdog: Miner ($Miner.Name {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Pools.$_.Name)"}) -join "; ")}) temporarily disabled. "
                    }
                    else { 
                        $WatchdogTimers = $WatchdogTimers -notmatch $WatchdogTimer
                    }
                }
            }
        }
    }
    if ($API) { $API.WatchdogTimers = $WatchdogTimers } #Give API access to WatchdogTimers information
    Start-Sleep $Config.Delay #Wait to prevent BSOD

    #Kill stray miners
    Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object { $AllMinerPaths -contains $_.ExecutablePath } | Where-Object { $ActiveMiners.ProcessID -notcontains $_.ProcessID } | Select-Object -ExpandProperty ProcessID | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction Ignore }
    $FailedMiners = @($null)
    if ($API.FailedMiners) { $API.FailedMiners = $null }
    $RunningMiners = @($ActiveMiners | Where-Object Best | Where-Object { $_.GetStatus() -eq "Running" })

    if ($ActiveMiners.Count -eq 0) { 
        Write-Log -Level Warn "No active miners available. "
        if ($Downloader) { $Downloader | Receive-Job -ErrorAction SilentlyContinue }
        Start-Sleep 10
        continue
    }

    #Start miners in the active list depending on if they are the most profitable
    $ActiveMiners | Where-Object Best | ForEach-Object { 
        $Miner = $_
        if ($_.GetStatus() -ne "Running") { 
            #Pre miner start exec
            $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PreStart"))).Trim()
            if ($Command) { Start-PrePostCommand -Command $Command -Event "PreStart" }
            Remove-Variable Command

            Write-Log "Starting miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Pools.$_.Name)"}) -join "; ")}). "
            Write-Log -Level Verbose $Miner.GetCommandLine().Replace("$(Convert-Path '.\')\", "")
            $Miner.SetStatus("Running")
            $Miner.Intervals = @()
            $Miner.StatusMessage = ""
            $RunningMiners += $Miner #Update API miner information
            if ($API) { $API.RunningMiners = $RunningMiners }

            #Post miner start exec
            $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PostStart"))).Trim()
            if ($Command) { Start-PrePostCommand -Command $Command -Event "PostStart" }
            Remove-Variable Command

            #Add watchdog timer
            if ($Config.Watchdog -and $Miner.Profit -ne $null) { 
                $Miner.Algorithm | ForEach-Object { 
                    $Miner_Algorithm = $_
                    $WatchdogTimer = $WatchdogTimers | Where-Object { $_.MinerName -eq $Miner.Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm }
                    if (-not $WatchdogTimer) { 
                        $WatchdogTimers += [PSCustomObject]@{ 
                            MinerName = $Miner.Name
                            PoolName  = $Pools.$Miner_Algorithm.Name
                            Algorithm = $Miner_Algorithm
                            Kicked    = $Timer
                        }
                    }
                    elseif (-not ($WatchdogTimer.Kicked -GT $Timer.AddSeconds( - $WatchdogReset))) { 
                        $WatchdogTimer.Kicked = $Timer
                    }
                }
            }
        }
        if ($Miner.Speed -contains $null) { 
            Write-Log -Level Warn "Benchmarking miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Pools.$_.Name)"}) -join "; ")})$(if ($Miner.IntervalMultiplier -gt 1) {" requires extended benchmark duration (Benchmarking interval $($_.Intervals.Count + 1)/$($_.IntervalMultiplier))"}) [Attempt $($_.GetActivateCount()) of max. $Strikes]. "
        }
        else { 
            if ($Config.MeasurePowerUsage -and $Miner.Algorithm | Where-Object { -not (Get-Stat -Name "$($Miner.Name)$(if (@($Miner.Algorithm).Count -eq 1) {"_$($Miner.Algorithm)"})_PowerUsage") }) { 
                Write-Log -Level Warn "Measuring power usage for miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Pools.$_.Name)"}) -join "; ")}). "
            }
        }
        if ($API) { $API.WatchdogTimers = $WatchdogTimers } #Give API access to WatchdogTimers information
    }
    Clear-Host


    #Display mining information
    [System.Collections.ArrayList]$Miner_Table = @(
        @{Width = [Int]($Miners.Name | Measure-Object Length -Maximum).maximum; Label = "Miner[Fee]"; Expression = { "$($_.Name)$(($_.Fees.PSObject.Properties.Value | ForEach-Object {"[{0:P2}]" -f [Double]$_}) -join '')" } }, 
        @{Width = [Int]($Miners | ForEach-Object { $_.HashRates.PSObject.Properties.Name -join "    " } | Measure-Object Length -Maximum).maximum; Label = "Algorithm"; Expression = { $Miner = $_; $_.HashRates.PSObject.Properties.Name } }, 
        @{Width = [Int]($(if ($MinersNeedingBenchmark.count) { 21 }), (($Miners | ForEach-Object { ($_.HashRates.PSObject.Properties.Value | ConvertTo-Hash) -join "      " } | Measure-Object Length -Maximum).maximum + 2) | Measure-Object -Maximum).Maximum; Label = "Speed"; Expression = { $Miner = $_; $_.HashRates.PSObject.Properties.Value | ForEach-Object { if ($_ -ne $null) { "$($_ | ConvertTo-Hash)/s" } else { $(if ($RunningMiners | Where-Object { $_.Path -eq $Miner.Path -and $_.Arguments -EQ $Miner.Arguments }) { "Benchmark in progress" } else { "Benchmark pending" }) } } }; Align = 'right' }
    )
    if ($PowerPrice) { 
        $Miner_Table.AddRange(@(
                #Mining Profits
                @{Width = [Int](7, ((ConvertTo-LocalCurrency -Value ($Miners.Profit | Sort-Object | Select-Object -First 1) -BTCRate ($Rates.BTC.$FirstCurrency)).Length) | Measure-Object -Maximum).Maximum; Label = "Profit`n$($FirstCurrency)/Day"; Expression = { if ($_.Profit) { ConvertTo-LocalCurrency -Value ($_.Profit) -BTCRate ($Rates.BTC.$FirstCurrency) -Offset 1 } else { "Unknown" } }; Align = "right" },
                @{Width = [Int](7, ((ConvertTo-LocalCurrency -Value ($Miners.Profit_Bias | Sort-Object | Select-Object -First 1) -BTCRate ($Rates.BTC.$FirstCurrency)).Length) | Measure-Object -Maximum).Maximum; Label = "Profit Bias`n$($FirstCurrency)/Day"; Expression = { if ($_.Profit_Bias) { ConvertTo-LocalCurrency -Value ($_.Profit_Bias) -BTCRate ($Rates.BTC.$FirstCurrency) -Offset 1 } else { "Unknown" } }; Align = "right" }
            ))
    }
    $Miner_Table.AddRange(@(
            #Miner earnings
            @{Width = [Int](7, ((ConvertTo-LocalCurrency -Value ($Miners.Earning | Sort-Object | Select-Object -First 1) -BTCRate ($Rates.BTC.$FirstCurrency)).Length) | Measure-Object -Maximum).Maximum; Label = "Earning`n$($FirstCurrency)/Day"; Expression = { if ($_.Earning) { ConvertTo-LocalCurrency -Value ($_.Earning) -BTCRate ($Rates.BTC.$FirstCurrency) -Offset 1 } else { "Unknown" } }; Align = "right" },
            @{Width = [Int](7, ((ConvertTo-LocalCurrency -Value ($Miners.Earning_Bias | Sort-Object | Select-Object -First 1) -BTCRate ($Rates.BTC.$FirstCurrency)).Length) | Measure-Object -Maximum).Maximum; Label = "Earning Bias`n$($FirstCurrency)/Day"; Expression = { if ($_.Earning_Bias) { ConvertTo-LocalCurrency -Value ($_.Earning_Bias) -BTCRate ($Rates.BTC.$FirstCurrency) -Offset 1 } else { "Unknown" } }; Align = "right" }
        ))
    if ($PowerPrice) { 
        $Miner_Table.AddRange(@(
                #PowerCost
                @{Width = [Int](7, ((ConvertTo-LocalCurrency -Value ($Miners.PowerCost | Sort-Object | Select-Object -First 1) -BTCRate ($Rates.BTC.$FirstCurrency)).Length) | Measure-Object -Maximum).Maximum; Label = "Power Cost`n$($FirstCurrency)/Day"; Expression = { if ($PowerPrice -eq 0) { "$(ConvertTo-LocalCurrency -Value 0 -BTCRate ($Rates.BTC.$FirstCurrency) -Offset 1)" } else { if ($_.PowerUsage) { "-$(ConvertTo-LocalCurrency -Value ($_.PowerCost) -BTCRate ($Rates.BTC.$FirstCurrency) -Offset 1)" } else { "Unknown" } } }; Align = "right" }
            ))
    }
    if ($Config.MeasurePowerUsage -and $Config.ShowPowerUsage) { 
        $Miner_Table.AddRange(@(
                #Power Usage
                @{Width = 12; Label = "Power Usage`nWatt"; Expression = { $Miner = $_; if ($_.PowerUsage -eq 0) { "0.00" } else { if ($_.PowerUsage) { "$($_.PowerUsage.ToString("N2"))" } else { if ($RunningMiners | Where-Object { $_.Path -eq $Miner.Path -and $_.Arguments -EQ $Miner.Arguments }) { "Measuring..." } else { "Unmeasured" } } } }; Align = "right" }
            ))
    }
    $Miner_Table.AddRange(@(
            @{Width = 12; Label = "Accuracy"; Expression = { $_.Pools.PSObject.Properties.Value | ForEach-Object { "{0:P0}" -f [Double](1 - $_.MarginOfError) } }; Align = 'right' }, 
            @{Width = 15; Label = "$($FirstCurrency)/GH/Day"; Expression = { $_.Pools.PSObject.Properties.Value | ForEach-Object { ConvertTo-LocalCurrency -Value ($_.Price * 1000000000) -BTCRate ($Rates.BTC.$FirstCurrency) -Offset 4 } }; Align = "right" }, 
            @{Width = [Int](($Miners | ForEach-Object Name | Measure-Object Length -Maximum).maximum + ($Miners | ForEach-Object CoinName | Measure-Object Length -Maximum).maximum); Label = "Pool[Fee]"; Expression = { $_.Pools.PSObject.Properties.Value | ForEach-Object { if ($_.CoinName) { "$($_.Name)-$($_.CoinName)$("[{0:P2}]" -f [Double]$_.Fee)" } else { "$($_.Name)$("[{0:P2}]" -f [Double]$_.Fee)" } } } }
        ))
    $Miners | Where-Object { $_.DeviceName -like "CPU*" -or $_.Earning_Unbias -ge 1E-6 -or $_.Earning -ge 1E-6 -or $_.Earning -eq $null -or ($Config.MeasurePowerUsage -and $_.PowerUsage -eq $null -and $_.Profit -ne 0) } | Sort-Object DeviceName, @{Expression = $( if ($Config.IgnorePowerCost) { "Earning_Bias" } else { "Profit_Bias" }); Descending = $True }, @{Expression = { $_.HashRates.PSObject.Properties.Name } } | Format-Table $Miner_Table -GroupBy @{Name = "Device$(if (@($_).count -ne 1) {"s"})"; Expression = { "$($_.DeviceName) [$(($Devices | Where-Object Name -eq $_.DeviceName).Model)]" } } | Out-Host
    Remove-Variable Miner_Table

    #Display benchmarking progress
    if ($MinersNeedingBenchmark) { 
        Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmark.count) miner$(if ($MinersNeedingBenchmark.count -gt 1){'s'}) left to complete benchmark."
    }
    #Display power usage progress
    if ($MinersNeedingPowerUsageMeasurement) { 
        Write-Log -Level Warn "Power usage measurement in progress: $($MinersNeedingPowerUsageMeasurement.count) miner$(if ($MinersNeedingPowerUsageMeasurement.count -gt 1) {'s'}) left to complete measuring."
    }

    #Display active miners list
    $ActiveMiners | Where-Object { $_.GetActivateCount() } | Sort-Object -Property @{Expression = { $_.GetStatus() }; Descending = $False }, @{Expression = { $_.GetActiveLast() }; Descending = $True } | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy @{Label = "Status"; Expression = { $_.GetStatus() } } (
        @{Label = "Last Speed"; Expression = { $_.Speed_Live | ForEach-Object { "$($_ | ConvertTo-Hash)/s" } }; Align = 'right' }, 
        @{Label = "Active"; Expression = { "{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.GetActiveTime() } }, 
        @{Label = "Launched"; Expression = { Switch ($_.GetActivateCount()) { 0 { "Never" } 1 { "Once" } Default { "$_ Times" } } } }, 
        @{Label = "Miner"; Expression = { $_.Name } }, 
        @{Label = "Command"; Expression = { $_.GetCommandLine().Replace("$(Convert-Path '.\')\", "") } }
    ) | Out-Host

    #Display watchdog timers
    $WatchdogTimers | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset) | Format-Table -Wrap (
        @{Label = "Miner"; Expression = { $_.MinerName } }, 
        @{Label = "Pool"; Expression = { $_.PoolName } }, 
        @{Label = "Algorithm"; Expression = { $_.Algorithm } }, 
        @{Label = "Watchdog Timer"; Expression = { "{0:n0} Seconds" -f ($Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds) }; Align = 'right' }
    ) | Out-Host

    #Display profit comparison
    if (-not ($BestMiners_Combo | Where-Object Profit -EQ $null) -and $Downloader.State -eq "Running") { $Downloader | Wait-Job -Timeout 10 | Out-Null }
    if (-not ($BestMiners_Combo | Where-Object Profit -EQ $null) -and $Downloader.State -ne "Running") { 
        $MinerComparisons =
        [PSCustomObject]@{"Miner" = "MultiPoolMiner" }, 
        [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object { "$($_.Name)-$($_.Algorithm -join '/')" } }

        $BestMiners_Combo_Stat = Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure-Object Profit -Sum).Sum -Duration $StatSpan

        $MinerComparisons_Profit = $BestMiners_Combo_Stat.Week, ($BestMiners_Combo_Comparison | Measure-Object Profit_Comparison -Sum).Sum

        $MinerComparisons_MarginOfError = $BestMiners_Combo_Stat.Week_Fluctuation, ($BestMiners_Combo_Comparison | ForEach-Object { $_.Profit_MarginOfError * (& { if ($MinerComparisons_Profit[1]) { $_.Profit_Comparison / $MinerComparisons_Profit[1] }else { 1 } }) } | Measure-Object -Sum).Sum

        $Config.Currency | Where-Object { $Rates.BTC.$_ } | ForEach-Object { 
            $MinerComparisons[0] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[0] * $Rates.BTC.$_), $MinerComparisons_MarginOfError[0], (($MinerComparisons_Profit[0] * $Rates.BTC.$_) / (1 + $MinerComparisons_MarginOfError[0])), (($MinerComparisons_Profit[0] * $Rates.BTC.$_) * (1 + $MinerComparisons_MarginOfError[0])))
            $MinerComparisons[1] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[1] * $Rates.BTC.$_), $MinerComparisons_MarginOfError[1], (($MinerComparisons_Profit[1] * $Rates.BTC.$_) / (1 + $MinerComparisons_MarginOfError[1])), (($MinerComparisons_Profit[1] * $Rates.BTC.$_) * (1 + $MinerComparisons_MarginOfError[1])))
        }

        if ([Math]::Round(($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1], 2) -gt 0) { 
            $MinerComparisons_Range = ($MinerComparisons_MarginOfError | Measure-Object -Average | Select-Object -ExpandProperty Average), (($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1]) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
            Write-Host -BackgroundColor Yellow -ForegroundColor Black "MultiPoolMiner is between $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])-$MinerComparisons_Range)*100)))% and $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])+$MinerComparisons_Range)*100)))% more profitable than the fastest miner: "
        }

        $MinerComparisons | Out-Host
        Remove-Variable MinerComparisons
    }


    #Display pool balances
    if ($Balances) { 
        Write-Host "Pool Balances: $(($Config.Currency | Where-Object {$Rates.$Currency.$_} | ForEach-Object {"$(($Balances | Where-Object {$Rates.($_.Currency).$Currency} | ForEach-Object {$_.Total * $Rates.($_.Currency).$Currency} | Measure-Object -Sum).Sum * $Rates.$Currency.$_) $($_)"}) -join " = ")"
    }

    #Display exchange rates
    $ExchangeRates = "Exchange Rates: $(($Config.Currency | Where-Object {$Rates.$Currency.$_} | ForEach-Object {"$($Rates.$Currency.$_) $($_)"}) -join " = ")"
    Write-Host $ExchangeRates
    if ($API) { 
        #Update ExchangeRates, CurrentEarning and CurrentProfit in API
        $API.ExchangeRates = $ExchangeRates
        if ($RunningMiners -and $Rates.BTC.$FirstCurrency) { 
            if ($MinersNeedingBenchmark -or $MinersNeedingPowerUsageMeasurement) { 
                $API.CurrentEarning = "Current Earning: N/A (Benchmarking)"; $API.CurrentProfit = "Current Profit: N/A (Benchmarking)"
            }
            else { 
                $API.MiningCost = "/NA"
                if ($MiningEarning) { 
                    $API.CurrentEarning = "Current Earning: $(($Rates.BTC | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {"$_ $(((($RunningMiners | Measure-Object -Sum -Property Earning).Sum) * $Rates.BTC.$_).ToString("N$((($Rates.BTC.$FirstCurrency).ToString().split('.') | Select-Object -Index 0).Length)"))"}) -join ' = ')"
                }
                if ($PowerPrice) { 
                    if ($Config.ShowPowerCost) { 
                        $API.MiningCost = "Current Power Cost: MiningCost"
                    }
                    if ($MiningProfit) { 
                        $API.CurrentProfit = "Current Profit: $(($Rates.BTC | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {"$_ $(((($RunningMiners | Measure-Object -Sum -Property Profit).Sum) * $Rates.BTC.$_).ToString("N$((($Rates.BTC.$FirstCurrency).ToString().split('.') | Select-Object -Index 0).Length)"))"}) -join ' = ')"
                    }
                }
                else { $API.CurrentProfit = "N/A" }
            }
        }
        else { $API.CurrentEarning = ""; $API.CurrentProfit = "" }
    }

    if ($MinersNeedingBenchmark.Count -eq 0 -and $MinersNeedingPowerUsageMeasurement.count -eq 0) { 
        if ($MiningEarning -lt $MiningCost) { 
            #Mining causes a loss
            Write-Host -BackgroundColor Yellow -ForegroundColor Black "Mining is currently NOT profitable and causes a loss of $FirstCurrency $(($MiningEarning - $MiningCost).ToString("N$((Get-Culture).NumberFormat.CurrencyDecimalDigits)"))/day (Earning: $($MiningEarning.ToString("N$((Get-Culture).NumberFormat.CurrencyDecimalDigits)"))/day; Cost: $($MiningCost.ToString("N$((Get-Culture).NumberFormat.CurrencyDecimalDigits)"))/day$(if ($Config.BasePowerUsage) {"; base power cost of $FirstCurrency $(($BasePowerCost * $Rates.BTC.$FirstCurrency).ToString("N$((Get-Culture).NumberFormat.CurrencyDecimalDigits)"))/day for $($Config.BasePowerUsage)W is included in the calculation"})). "
        }
        if (($MiningEarning - $MiningCost) -lt $Config.ProfitabilityThreshold) { 
            #Mining profit is below the configured threshold
            Write-Host -BackgroundColor Yellow -ForegroundColor Black "Mining profit is below the configured threshold of $FirstCurrency $($Config.ProfitabilityThreshold.ToString("N$((Get-Culture).NumberFormat.CurrencyDecimalDigits)"))/day; mining is suspended until threshold is reached."
        }
    }


    #Read hash rate info from miners as to not overload the APIs and display miner download status
    if ($Intervals.Count -eq 0 -or $MinersNeedingBenchmark -or $MinersNeedingPowerUsageMeasurement) { 
        #Enforce full benchmark interval time on first (benchmark) loop
        $StatEnd = (Get-Date).ToUniversalTime().AddSeconds($Config.BenchmarkInterval)
        $StatSpan = New-TimeSpan $StatStart $StatEnd
    }

    Write-Log "Start waiting before next run. "
    $PollStart = (Get-Date).ToUniversalTime()
    $PollEnd = $PollStart
    $ExpectedHashRateSamples = 1

    Do { 

        if ($Downloader) { $Downloader | Receive-Job -ErrorAction SilentlyContinue }

        $RunningMiners | Where-Object { $_.GetStatus() -eq "Running" } | Sort-Object { @($_.Data | Sort-Object Date) } | ForEach-Object { 
            $Miner = $_
            if (($Miner.Data | Where-Object Date -GT $PollStart).count -lt $ExpectedHashRateSamples -and ($Miner.Data | Where-Object Date -GT $PollStart).count -lt $Config.HashRateSamplesPerInterval) { 
                $Miner_Data = $Miner.UpdateMinerData()
                $Sample = $Miner.Data | Where-Object Date -GE $PollEnd | Select-Object -last 1
                if ($Sample) { 
                    Write-Log -Level Verbose "$($Miner.Name) data sample retrieved: [$(($Sample.Hashrate.PSObject.Properties.Name | ForEach-Object {"$_ = $(($Sample.Hashrate.$_ | ConvertTo-Hash) -replace ' ')"}) -join '; ')$(if ($Sample.PowerUsage) {" / $($Sample.PowerUsage.ToString("N2"))W"})$(if ($Miner.AllowedBadShareRatio) {" / Shares Accepted: $($Sample.Shares[0]); Rejected: $($Sample.Shares[1]); Total: $($Sample.Shares[2])"})]"
                }
                elseif ($Miner.WarmupTime -and (Get-Date).ToUniversalTime().AddSeconds(- $Miner.WarmupTime) -gt $PollStart -and -not @($Miner.Data | Where-Object Date -GT (Get-Date).ToUniversalTime().AddSeconds(- $Miner.WarmupTime))) { 
                    #No data samples received for more than $warmup seconds, set miner idle
                    #Pre miner stop exec
                    $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PreStop"))).Trim()
                    if ($Command) { Start-PrePostCommand -Command $Command -Event "PreStop" }
                    Remove-Variable Command

                    $Miner.StatusMessage = " was stopped because MPM could not retrieve hash rate information from the miner API within $($Miner.WarmupTime) seconds"
                    $Miner.SetStatus("Idle")

                    #Post miner stop exec
                    $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PostStop"))).Trim()
                    if ($Command) { Start-PrePostCommand -Command $Command -Event "PostStop" }
                    Remove-Variable Command
                }
            }
        }
        $RunningMiners | Where-Object { $_.GetStatus() -ne "Running" } | ForEach-Object { 
            #Failed miner detected
            $Miner = $_
            Write-Log -Level Error "Miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Pools.$_.Name)"}) -join "; ")})$(if ($Miner.StatusMessage) {$Miner.StatusMessage} else {" has failed"}). "
            if ($Miner.New) { $Miner.Benchmarked-- }
            $RunningMiners = @($RunningMiners | Where-Object { $_ -ne $Miner })
            $FailedMiners += $Miner

            #Post miner failure exec
            $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PostFailure"))).Trim()
            if ($Command) { Start-PrePostCommand -Command $Command -Event "PostFailure" }
            Remove-Variable Command
        }
            
        $Miner.Speed_Live = [Double[]]@()
        $Miner.Algorithm | ForEach-Object { 
            $Miner_Algorithm = $_
            $Miner_Speed = [Double]($Miner.GetHashRate($Miner_Algorithm, $false))
            $Miner.Speed_Live += [Double]$Miner_Speed
        }

        # Update API information
        if ($API) { 
            $API.RunningMiners = $RunningMiners
            $API.FailedMiners = $FailedMiners
            $API.AllDevices | ForEach-Object { if ($Devices.Name -contains $_.Name) { $Device = $_; if ($Miner = $ActiveMiners | Where-Object { $_.DeviceName -contains $Device.Name } | Select-Object -Unique) { $Device | Add-Member Status $Miner.GetStatus() -Force } else { $Device | Add-Member Status "Idle" -Force } } else { $_ | Add-Member Status "Disabled" -Force } }
            Update-APIDeviceStatus $API $Devices
        }

        if (-not $RunningMiners) { 
            #No more running miners, start new loop immediately
            Write-Log "No more running miners, start new loop immediately. "
            $MinimumReceivedHashRateSamples = $HashRateSamplesPerInterval
            break
        }

        if ($ActiveMiners | Where-Object Best | Where-Object { $Miner_Name = $_.Name; $_.Algorithm | Where-Object { -not (Get-Stat -Name "$($Miner_Name)_$($_)_HashRate") } }) { 
            #We're benchmarking
            if (-not ($RunningMiners | Where-Object { $_.GetStatus() -eq "Running" } | Where-Object { $Miner_Name = $_.Name; $_.Algorithm | Where-Object { -not (Get-Stat -Name "$($Miner_Name)_$($_)_HashRate") } })) { 
                #All benchmarking miners have failed, start new loop immediately
                Write-Log "All benchmarking miners have failed, start new loop immediately. "
                $MinimumReceivedHashRateSamples = $HashRateSamplesPerInterval
                break
            }
        }
        elseif ($ActiveMiners | Where-Object Best | Where-Object { $_.GetStatus() -ne "Running" }) { 
            #A non benchmarking miner has failed, start new loop immediately
            Write-Log "A non benchmarking miner has failed, start new loop immediately. "
            $MinimumReceivedHashRateSamples = $HashRateSamplesPerInterval
            break
        }

        #Preload pool information - code to be removed
        if ((-not $NewPools_Jobs) -and (Test-Path "Pools" -PathType Container -ErrorAction Ignore) -and ((($StatEnd - (Get-Date).ToUniversalTime()).TotalSeconds) -le $($NewPools_JobsDurations | Measure-Object -Average).Average)) { 
            if (-not ($RunningMiners | Where-Object { $_.GetStatus() -eq "Running" } | Where-Object { $_.DeviceName -like "CPU#*" })) {
                #no pre-loading when cpu miners are running
                if ($PoolsRequest = @(Get-ChildItem "Pools" -File | Where-Object { $Config.Pools.$($_.BaseName) -and $Config.ExcludePoolName -inotcontains $_.BaseName } | Where-Object { $Config.PoolName.Count -eq 0 -or $Config.PoolName -contains $_.BaseName } | Sort-Object BaseName)) { 
                    $Config | Add-Member "PoolList" @($PoolsRequest.BaseName) -Force
                    Write-Log "Pre-Loading pool information ($($Config.PoolList -join '; ')). "
                    $NewPools_Jobs = @(
                        $PoolsRequest | ForEach-Object { 
                            $Pool_Name = $_.BaseName
                            $Pool_Parameters = @{StatSpan = $StatSpan; Config = $Config; JobName = "Pool_$($_.BaseName)" }
                            $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object { $Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name) }
                            Get-ChildItemContent "Pools\$($_.Name)" -Parameters $Pool_Parameters -Threaded
                        } | Select-Object
                    )
                    if ($API) { $API.NewPools_Jobs = $NewPools_Jobs } #Give API access to pool jobs information
                }
                Remove-Variable PoolsRequest
            }
        }
        $PollDuration = ($StatEnd - $PollStart).TotalSeconds / $Config.HashRateSamplesPerInterval
        $ExpectedHashRateSamples = [math]::Round(((((Get-Date).ToUniversalTime() - $PollStart).TotalSeconds) + $PollDuration) / $PollDuration)
        $MinimumReceivedHashRateSamples = [Int](@($RunningMiners | ForEach-Object { @($_.Data | Where-Object Date -GE $PollStart).Count } | Measure-Object -Minimum).Minimum)
        $HashRateSamples = @($RunningMiners | ForEach-Object { @($_.Data | Where-Object Date -GE $PollStart).Count })
        $PollEnd = (Get-Date).ToUniversalTime()

        if (-not $MinimumReceivedHashRateSamples) { 
            Start-Sleep 1
        }
        elseif ($MinimumReceivedHashRateSamples -ge $ExpectedHashRateSamples -and (Get-Date).ToUniversalTime() -le $StatEnd) { 
            Start-Sleep 1
        }
        elseif ($MinimumReceivedHashRateSamples -ge $HashRateSamplesPerInterval -and (Get-Date).ToUniversalTime() -le $StatEnd) { 
            Start-Sleep ($StatEnd - (Get-Date).ToUniversalTime()).TotalSeconds
        }
        if ((Get-Date).ToUniversalTime() -ge $StatEnd -and $MinimumReceivedHashRateSamples -lt $ExpectedHashRateSamples -and $MinimumReceivedHashRateSamples -lt $Config.MinHashRateSamples) { 
            if (($RunningMiners | Where-Object { $Miner_Name = $_.Name; $_.Algorithm | Where-Object { -not (Get-Stat -Name "$($Miner_Name)_$($_)_HashRate") } }) -or ($Config.MeasurePowerUsage -and ($RunningMiners | Where-Object { -not $_.PowerUsage }))) { 
                #Benchmarking or power measuring miner found
                if ((Get-Date).ToUniversalTime() -lt $StatStart.AddSeconds(3 * $Config.BenchmarkInterval)) { 
                    #Limit extension to max. 3x BenchmarkInterval
                    $StatEnd = (Get-Date).ToUniversalTime().AddSeconds(1)
                    $StatSpan = New-TimeSpan $StatStart $StatEnd
                }
            }
        }
    } While ((Get-Date).ToUniversalTime() -lt $StatEnd)

    #In case effective loop time was longer than configured interval
    $StatEnd = (Get-Date).ToUniversalTime()
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    $Intervals += "$StatStart - $StatEnd"
    if ($API) { $API.Intervals = $Intervals }

    if ($MinimumReceivedHashRateSamples -lt $HashRateSamplesPerInterval -and ($HashRateSamples | Measure-Object -Minimum).Minimum -gt 0 -and $Intervals.Count -gt 1 -and ($HashRateSamples | Measure-Object -Maximum).Maximum -lt $HashRateSamplesPerInterval) { Write-Log -Level Warn "Collected hash rate samples during last interval ($($StatStart.ToLocalTime().ToLongTimeString()) - $($StatEnd.ToLocalTime().ToLongTimeString())) for all miners: $($HashRateSamples -join ', '); configured number of samples is $($HashRateSamplesPerInterval). If you see this message frequently then increase '-interval' time." }

    Remove-Variable PollDuration -ErrorAction SilentlyContinue
    Remove-Variable ExpectedHashRateSamples -ErrorAction SilentlyContinue
    Remove-Variable MinimumReceivedHashRateSamples -ErrorAction SilentlyContinue
    Remove-Variable HashRateSamples -ErrorAction SilentlyContinue
    Remove-Variable PollEnd -ErrorAction SilentlyContinue

    Write-Log "Finish waiting before next run. "

    #Set watchdog times
    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

    #Save current hash rates and power usage data
    Write-Log "Retrieving hash rates and power usage data. "
    $ActiveMiners | Where-Object Best | ForEach-Object { 
        $Miner = $_
        $Miner.Speed_Live = [Double[]]@()
        $Miner.Intervals += $StatSpan
        $Miner_Name = $Miner.Name

        #Keep the last 50 data samples (IntervalMultiplier * more for miners with extended benchmark interval)
        $Miner.Data = @($Miner.Data | Select-Object -Last (50 * $Miner.IntervalMultiplier))

        if ($Miner.New) { $Miner.New = [Boolean]($Miner.Algorithm | Where-Object { -not (Get-Stat -Name "$($Miner_Name)_$($_)_HashRate") }) }

        if ($Miner.New) { $Miner.Benchmarked++ }

        if ($Miner.GetStatus() -eq "Running" -or $Miner.New) { 
            #Read power usage from miner data
            $Miner_PowerUsage = [Double]($Miner.GetPowerUsage(-not (Get-Stat -Name "$($Miner_Name)$(if (@($Miner.Algorithm).Count -eq 1) {"_$($Miner.Algorithm)"})_PowerUsage") -and $Miner.Benchmarked -lt $Miner.IntervalMultiplier))
            if (($Miner_PowerUsage -and $Miner.Intervals.Count -ge $Miner.IntervalMultiplier) -or $Miner.Intervals.Count -ge ($Miner.IntervalMultiplier + $Strikes) -or $Miner.GetActivateCount() -ge $Strikes) { 
                Write-Log -Level Verbose "Saving power usage ($($Miner_Name)$(if (@($Miner.Algorithm).Count -eq 1) {"_$($Miner.Algorithm)"})_PowerUsage: $($Miner_PowerUsage.ToString("N2"))W)$(if  (-not (Get-Stat -Name "$($Miner_Name)$(if (@($Miner.Algorithm).Count -eq 1) {"_$($Miner.Algorithm)"})_PowerUsage")) {" [Power measurement done]"})"
                $Stat = Set-Stat -Name  "$($Miner_Name)$(if (@($Miner.Algorithm).Count -eq 1) {"_$($Miner.Algorithm)"})_PowerUsage" -Value $Miner_PowerUsage -Duration ([Long]($Miner.Intervals | Measure-Object Ticks -Sum).Sum) -FaultDetection ($Miner.IntervalMultiplier -le 1)
            }

            #Read miner speed from miner data
            $Miner.Algorithm | ForEach-Object { 
                $Miner_Algorithm = $_
                $Miner_Speed = [Double]($Miner.GetHashRate($Miner_Algorithm, ($Miner.New -and $Miner.Benchmarked -lt $Miner.IntervalMultiplier)))
                $Miner.Speed_Live += [Double]$Miner_Speed
                if (($Miner_Speed -and $Miner.Intervals.Count -ge $Miner.IntervalMultiplier) -or $Miner.Intervals.Count -ge ($Miner.IntervalMultiplier + $Strikes) -or $Miner.GetActivateCount() -ge $Strikes) { 
                    Write-Log -Level Verbose "Saving hash rate ($($Miner_Name)_$($Miner_Algorithm)_HashRate: $(($Miner_Speed | ConvertTo-Hash) -replace ' '))$(if  (-not (Get-Stat -Name "$($Miner_Name)_$($Miner_Algorithm)_HashRate")) {" [Benchmark done]"})"
                    $Stat = Set-Stat -Name "$($Miner_Name)_$($Miner_Algorithm)_HashRate" -Value $Miner_Speed -Duration ([Long]($Miner.Intervals | Measure-Object Ticks -Sum).Sum) -FaultDetection ($Miner.IntervalMultiplier -le 1)
                    if (-not $Miner_Speed) { 
                        Write-Log -Level Warn "Miner ($($Miner_Name) {$($Miner_Algorithm)@$($Pools.$Miner_Algorithm.Name)}) did not report any valid hashrate and will be disabled. To re-enable remove the stats file ($($Miner.Name)_$($_)_HashRate.txt). "
                    }
                }

                #Update watchdog timer
                $WatchdogTimer = $WatchdogTimers | Where-Object { $_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm }
                if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) { 
                    $WatchdogTimer.Kicked = $Stat.Updated
                }
                #Always kick watchdog for running miners with at least one and less than MinHashRateSamples hash rate samples in current loop
                elseif ($WatchdogTimer -and (($Miner.Speed -contains $null) -and ($Miner.Data | Where-Object Date -GE $StatStart).Count -and $Miner.Data | Where-Object Date -GE $StatStart).Count -lt $Config.MinHashRateSamples) { 
                    $WatchdogTimer.Kicked = (Get-Date).ToUniversalTime()
                }
            }
        }
    }
    #Benchmarking: Stop all CPU miners (otherwise the loop might take ages)
    if ($MinersNeedingBenchmark) { 
        $RunningMiners | Where-Object { $_.GetStatus() -eq "Running" } | Where-Object { $_.DeviceName -like "CPU#*" } | Foreach-Object { 
            $Miner = $_
            #Pre miner failure exec
            $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PreStop"))).Trim()
            if ($Command) { Start-PrePostCommand -Command $Command -Event "PreStop" }
            Write-Log "Stopping miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_)@$($Miner.PoolName | Select-Object -Index ([array]::indexof($Miner.Algorithm, $_)))"}) -join "; ")}). "
            $Miner.SetStatus("Idle")
            $Miner.StatusMessage = " stopped gracefully"
            #Post miner stop exec
            $Command = ($ExecutionContext.InvokeCommand.ExpandString((Get-PrePostCommand -Miner $Miner -Config $Config -Event "PostStop"))).Trim()
            if ($Command) { Start-PrePostCommand -Command $Command -Event "PostStop" }
            $RunningMiners = @($RunningMiners | Where-Object { $_ -ne $Miner })
            if ($API) { $API.RunningMiners = $RunningMiners }
        }
    }

    #Reduce memory
    #Get-Job -State Completed | Receive-Job -Wait -AutoRemoveJob
    $Error.Clear()
    [GC]::Collect()

    Write-Log "Starting next run. "
}

Write-Log "Stopping MultiPoolMiner® v$Version © 2017-$((Get-Date).Year) MultiPoolMiner.io"

#Stop the log
Stop-Transcript

exit
