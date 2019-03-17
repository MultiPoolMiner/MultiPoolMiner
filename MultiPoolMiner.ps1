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
    [Array]$DeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeDeviceName = @(), #i.e. CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc. will not be used for mining
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = @(), #i.e. Ethash, Equihash, CryptoNightV7 etc.
    [Parameter(Mandatory = $false)]
    [Array]$CoinName = @(), #i.e. Monero, Zcash etc.
    [Parameter(Mandatory = $false)]
    [Array]$MiningCurrency = @(), #i.e. LUX, XVG etc.
    [Parameter(Mandatory = $false)]
    [Alias("Miner")]
    [Array]$MinerName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("Pool")]
    [Array]$PoolName = @(), 
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeAlgorithm = @(), #i.e. Ethash, Equihash, CryptoNightV7 etc.
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeCoinName = @(), #i.e. Monero, Zcash etc.
    [Parameter(Mandatory = $false)]
    [Array]$ExcludeMiningCurrency = @(), #i.e. LUX, XVG etc.
    [Parameter(Mandatory = $false)]
    [Alias("ExcludeMiner")]
    [Array]$ExcludeMinerName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("ExcludePool")]
    [Array]$ExcludePoolName = @(), 
    [Parameter(Mandatory = $false)]
    [Alias("DisableDualMining")]
    [Switch]$SingleAlgoMining = $false, #disables all dual mining miners
    [Parameter(Mandatory = $false)]
    [Array]$Currency = ("BTC", "USD"), #i.e. GBP, EUR, ZEC, ETH etc., the first currency listed will be used as base currency for profit calculations
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
    [Double]$SwitchingPrevention = 1, #zero does not prevent miners switching
    [Parameter(Mandatory = $false)]
    [Switch]$ShowMinerWindow = $false, #if true most miner windows will be visible (they can steal focus) - miners that use the 'Wrapper' API will still remain hidden
    [Parameter(Mandatory = $false)]
    [Switch]$UseFastestMinerPerAlgoOnly = $false, #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    [Parameter(Mandatory = $false)]
    [Alias("IgnoreFees")]
    [Switch]$IgnoreCosts = $false, #if $true MPM will ignore miner and pool fees for its calculations (as older versions did)
    [Parameter(Mandatory = $false)]
    [Switch]$CreateMinerInstancePerDeviceModel = $false, #if true MPM will create separate miner instances per device model. This will improve profitability.
    [Parameter(Mandatory = $false)]
    [Switch]$UseDeviceNameForStatsFileNaming = $false, #if true the benchmark files will be named like 'NVIDIA-CryptoDredge-2xGTX1080Ti_Lyra2RE2_HashRate'. This will keep benchmarks files valid even when the order of the cards are changed in your rig
    [Parameter(Mandatory = $false)]
    [String]$ConfigFile = ".\Config.txt", #default config file
    [Parameter(Mandatory = $false)]
    [Switch]$RemoteAPI = $false,
    [Parameter(Mandatory = $false)]
    [ValidateRange(0.0, 1.0)]
    [Double]$PricePenaltyFactor = 1 #Estimated profit as projected by pool will be multiplied by this facator. Allowed values: 0.0 - 1.0
)

Clear-Host

$Version = "3.2.0"
$VersionCompatibility = "3.2.0"
$Strikes = 3
$SyncWindow = 5 #minutes
$ProgressPreference = "silentlyContinue"

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Import-Module NetSecurity -ErrorAction Ignore
Import-Module Defender -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore

$Algorithm = $Algorithm | ForEach-Object {@(@(Get-Algorithm ($_ -split '-' | Select-Object -First 1) | Select-Object) + @($_ -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'}
$ExcludeAlgorithm = $ExcludeAlgorithm | ForEach-Object {@(@(Get-Algorithm ($_ -split '-' | Select-Object -First 1) | Select-Object) + @($_ -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'}
$Region = $Region | ForEach-Object {Get-Region $_}
$Currency = $Currency | ForEach-Object {$_.ToUpper()}

$Timer = (Get-Date).ToUniversalTime()
$StatEnd = $Timer
$DecayStart = $Timer
$DecayPeriod = 60 #seconds
$DecayBase = 1 - 0.1 #decimal percentage

$WatchdogTimers = @()

$ActiveMiners = @()

#Start the log
Start-Transcript ".\Logs\MultiPoolMiner_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

Write-Log "Starting MultiPoolMiner® v$Version © 2017-$((Get-Date).Year) MultiPoolMiner.io"

#Unblock files
if (Get-Command "Unblock-File" -ErrorAction Ignore) {Get-ChildItem . -Recurse | Unblock-File}
if ((Get-Command "Get-MpPreference" -ErrorAction Ignore) -and (Get-MpComputerStatus -ErrorAction Ignore) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

#Initialize the API
Import-Module .\API.psm1
Start-APIServer
$API.Version = $Version

#Initialize config file
if (-not [IO.Path]::GetExtension($ConfigFile)) {$ConfigFile = "$($ConfigFile).txt"}
$Config_Temp = [PSCustomObject]@{}
$Config_Parameters = @{}
$MyInvocation.MyCommand.Parameters.Keys | Sort-Object | ForEach-Object {
    $Config_Parameters.$_ = Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue
    if ($Config_Parameters.$_ -is [Switch]) {$Config_Parameters.$_ = [Boolean]$Config_Parameters.$_}
    $Config_Temp | Add-Member @{$_ = "`$$_"}
}
$Config_Temp | Add-Member @{Pools = @{}} -Force
$Config_Temp | Add-Member @{Miners = @{}} -Force
$Config_Temp | Add-Member @{Wallets = @{BTC = "`$Wallet"}} -Force
$Config_Temp | Add-Member @{VersionCompatibility = $VersionCompatibility} -Force
if (-not (Test-Path $ConfigFile -PathType Leaf -ErrorAction Ignore)) {$Config_Temp | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile}
$Config = [PSCustomObject]@{}

#Set donation parameters
$LastDonated = $Timer.AddDays(-1).AddHours(1)
$WalletDonate = ((@("1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb") * 3) + (@("16Qf1mEk5x2WjJ1HhfnvPnqQEi2fvCeity") * 2) + (@("1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF") * 2))[(Get-Random -Minimum 0 -Maximum ((3 + 2 + 2) - 1))]
$UserNameDonate = ((@("aaronsace") * 3) + (@("grantemsley") * 2) + (@("uselessguru") * 2))[(Get-Random -Minimum 0 -Maximum ((3 + 2 + 2) - 1))]
$WorkerNameDonate = "multipoolminer"

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

while (-not $API.Stop) {
    #Display downloader progress
    if ($Downloader) {$Downloader | Receive-Job}

    #Reduce memory
    Get-Job -State Completed | Receive-Job -Wait -AutoRemoveJob
    $Error.Clear()
    [GC]::Collect()

    #Load the configuration
    $OldConfig = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $Config = Get-ChildItemContent $ConfigFile -Parameters $Config_Parameters | Select-Object -ExpandProperty Content
    if ($Config.Proxy) {$PSDefaultParameterValues["*:Proxy"] = $Config.Proxy}
    else {$PSDefaultParameterValues.Remove("*:Proxy")}
    if (-not $Config.MinerStatusKey -and $Config.Wallets.BTC) {$Config | Add-Member MinerStatusKey $Config.Wallets.BTC -Force} #for backward compatibility
    $Config | Add-Member Pools ([PSCustomObject]@{}) -ErrorAction Ignore
    Get-ChildItem "Pools" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | ForEach-Object {
        $Config.Pools | Add-Member $_ ([PSCustomObject]@{}) -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member User $Config.UserName -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member Worker $Config.WorkerName -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member Wallets $Config.Wallets -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member API_ID $Config.API_ID -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member API_Key $Config.API_Key -ErrorAction Ignore
        $Config.Pools.$_ | Add-Member PricePenaltyFactor $Config.PricePenaltyFactor -ErrorAction Ignore
    }
    $Config | Add-Member Miners ([PSCustomObject]@{}) -ErrorAction Ignore
    Get-ChildItem "Miners" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | ForEach-Object {
        $Config.Miners | Add-Member $_ ([PSCustomObject]@{}) -ErrorAction Ignore
    }
    Get-ChildItem "MinersLegacy" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | ForEach-Object {
        $Config.Miners | Add-Member $_ ([PSCustomObject]@{}) -ErrorAction Ignore
    }
    $BackupConfig = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    if (-not $Config.VersionCompatibility -or [System.Version]$Config.VersionCompatibility -lt [System.Version]$VersionCompatibility) {
        Write-Log -Level Error "Config file ($ConfigFile) is not a valid configuration file (min. required config file version is $VersionCompatibility). Cannot continue. "
        Start-Sleep 10
        continue
    }
    $API.Config = $BackupConfig #Give API access to the current running configuration

    #Unprofitable algorithms
    if (Test-Path ".\UnprofitableAlgorithms.txt" -PathType Leaf -ErrorAction Ignore) {$UnprofitableAlgorithms = [Array](Get-Content ".\UnprofitableAlgorithms.txt" | ConvertFrom-Json -ErrorAction SilentlyContinue | Sort-Object -Unique)} else {$UnprofitableAlgorithms = @()}

    #Activate or deactivate donation
    if ($Config.Donate -lt 10) {$Config.Donate = 10}
    if ($Timer.AddDays(-1).AddMinutes(-1).AddSeconds(1) -ge $LastDonated) {$LastDonated = $Timer}
    if ($Timer.AddDays(-1).AddMinutes($Config.Donate) -ge $LastDonated) {
        if ($WalletDonate -and $UserNameDonate -and $WorkerNameDonate) {
            Write-Log "Donation run, mining to donation address for the next $(($LastDonated - ($Timer.AddDays(-1))).Minutes +1) minutes. Note: MPM will use ALL available pools. "
            $Config | Add-Member Pools ([PSCustomObject]@{}) -Force
            Get-ChildItem "Pools" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | ForEach-Object {
                $Config.Pools | Add-Member $_ ([PSCustomObject]@{
                        User               = $UserNameDonate
                        Worker             = $WorkerNameDonate
                        Wallets            = [PSCustomObject]@{BTC = $WalletDonate}
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

    if (Test-Path "APIs" -PathType Container -ErrorAction Ignore) {Get-ChildItem "APIs" -File | ForEach-Object {. $_.FullName}}

    #Set master timer
    $Timer = (Get-Date).ToUniversalTime()
    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Config.Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd
    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)
    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

    #Load information about the devices
    $Devices = @(Get-Device -Name @($Config.DeviceName) -ExcludeName @($Config.ExcludeDeviceName | Select-Object) -Refresh:([Boolean]((Compare-Object @($Config.DeviceName | Select-Object) @($OldConfig.DeviceName | Select-Object)) -or (Compare-Object @($Config.ExcludeDeviceName | Select-Object) @($OldConfig.ExcludeDeviceName | Select-Object)))) | Select-Object)
    $API.Devices = $Devices #Give API access to the device information
    if ($Devices.Count -eq 0) {
        Write-Log -Level Warn "No mining devices found. "
        while ((Get-Date).ToUniversalTime() -lt $StatEnd) {Start-Sleep 10}
        continue
    }

    #Load information about the pools
    if (Test-Path "Pools" -PathType Container -ErrorAction Ignore) {
        Write-Log "Loading pool information. "
        $NewPools_Jobs = @(
            Get-ChildItem "Pools" -File | Where-Object {$Config.Pools.$($_.BaseName) -and $Config.ExcludePoolName -inotcontains $_.BaseName} | Where-Object {$Config.PoolName.Count -eq 0 -or $Config.PoolName -contains $_.BaseName} | ForEach-Object {
                $Pool_Name = $_.BaseName
                $Pool_Parameters = @{StatSpan = $StatSpan}
                $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object {$Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name)}
                Get-ChildItemContent "Pools\$($_.Name)" -Parameters $Pool_Parameters -Threaded
            } | Select-Object
        )
    }

    #Load information about the balances
    if (Test-Path "Balances" -PathType Container -ErrorAction Ignore) {
        Write-Log "Loading balances information. "
        $Balances_Jobs = @(
            Get-ChildItem "Balances" -File | Where-Object {$BackupConfig.Pools.$($_.BaseName) -and $BackupConfig.ExcludePoolName -inotcontains $_.BaseName} | Where-Object {$BackupConfig.PoolName.Count -eq 0 -or $BackupConfig.PoolName -contains $_.BaseName} | ForEach-Object {
                $Pool_Name = $_.BaseName
                $Pool_Parameters = @{}
                $BackupConfig.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object {$Pool_Parameters.($_.Name) = $BackupConfig.Pools.$Pool_Name.($_.Name)}
                Get-ChildItemContent "Balances\$($_.Name)" -Parameters $Pool_Parameters -Threaded
            } | Select-Object
        )
    }

    #Update monitoring service
    if ($ActiveMiners -and $Config.MinerStatusURL -and $Config.MinerStatusKey) {
        $ReportStatus_Job | Remove-Job -Force -ErrorAction SilentlyContinue
        $ReportStatus_Job = & .\ReportStatus.ps1 $Config $ActiveMiners
    }

    #Wait 10 to 30 seconds to read miner hash rates
    Write-Log "Reading hash rates. "
    for ($i = 0; $i -lt $Strikes -and ($i -lt 1 -or (($Timer.AddSeconds($Strikes * 10) -lt $StatEnd -or ($ActiveMiners | Where-Object {$_.GetStatus() -eq "Running"} | Where-Object {$_.New})) -and ($ActiveMiners | Where-Object {$_.GetStatus() -eq "Running"}))); $i++) {
        Start-Sleep 10
        $Timer = (Get-Date).ToUniversalTime()

        $ActiveMiners | ForEach-Object {
            $Miner = $_
            $Miner.UpdateMinerData() | ForEach-Object {Write-Log -Level Verbose "$($Miner.Name): $($Miner.Data | ForEach-Object {$_})"}
        }

        $API.RunningMiners = $ActiveMiners | Where-Object Best
    }

    #Update monitoring service
    if ($ActiveMiners -and $Config.MinerStatusURL -and $Config.MinerStatusKey) {
        $ReportStatus_Job | Remove-Job -Force -ErrorAction SilentlyContinue
        $ReportStatus_Job = & .\ReportStatus.ps1 $Config $ActiveMiners
    }

    #Save current hash rates
    Write-Log "Saving hash rates. "
    $ActiveMiners | Where-Object Best | ForEach-Object {
        $Miner = $_
        $Miner.Speed_Live = @()
        $Miner.Intervals += $StatSpan

        if ($Miner.New) {$Miner.New = $Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_)_HashRate")}}

        if ($Miner.Intervals.Count % $Miner.IntervalMultiplier -eq 0 -or ($Miner.New -and $Miner.Intervals.Count -ge $Miner.IntervalMultiplier)) {
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_ -replace "-NHMP" #temp fix
                $Miner.Speed_Live += $Miner.GetHashRate($Miner_Algorithm, (($Miner.Intervals | Select-Object -Last $Miner.IntervalMultiplier | Measure-Object TotalSeconds -Sum).Sum + $Config.Interval), $false)

                $Miner_Speed = $Miner.GetHashRate($Miner_Algorithm, (($Miner.Intervals | Select-Object -Last $Miner.IntervalMultiplier | Measure-Object TotalSeconds -Sum).Sum + $Config.Interval), $Miner.New)
                if (-not $Miner_Speed -and $Miner.Intervals.Count -ge ($Strikes * $Miner.IntervalMultiplier)) {$Miner_Speed = $Miner.GetHashRate($Miner_Algorithm, (($Miner.Intervals | Select-Object -Last $Miner.IntervalMultiplier | Measure-Object TotalSeconds -Sum).Sum + $Config.Interval), $false)}
                if (-not $Miner_Speed -and $Miner.Intervals.Count -ge ($Strikes * $Strikes * $Miner.IntervalMultiplier) -and $Miner.New) {$Miner_Speed = $Miner.GetHashRate($Miner_Algorithm, (($Miner.Intervals | Measure-Object TotalSeconds -Sum).Sum + $Config.Interval), $false)}
                if ($Miner_Speed -or $Miner.Intervals.Count -ge ($Strikes * $Strikes * $Miner.IntervalMultiplier) -or ($Miner.New -and $Miner.GetActivateCount() -gt $Strikes)) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Value $Miner_Speed -Duration ([Long]($Miner.Intervals | Measure-Object Ticks -Sum).Sum) -FaultDetection ($Miner.IntervalMultiplier -le 1)
                }
                if ($Miner_Speed) {$Miner.Intervals = @()}

                #Update watchdog timer
                $Miner_Name = $Miner.Name
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                    $WatchdogTimer.Kicked = $Stat.Updated
                }
            }
        }
    }

    #Retrieve collected balance data
    if ($Balances_Jobs) {
        $Balances = $Balances_Jobs | Receive-Job -Wait -AutoRemoveJob | Select-Object -ExpandProperty Content
        $Balances_Jobs = $null
    }

    #Update the exchange rates
    Write-Log "Updating exchange rates from CryptoCompare. "
    try {
        $NewRates = Invoke-RestMethod "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$((@([PSCustomObject]@{Currency = "BTC"}) + @($Balances) | Select-Object -ExpandProperty Currency -Unique | ForEach-Object {$_.ToUpper()}) -join ",")&tsyms=$(($Config.Currency | ForEach-Object {$_.ToUpper()}) -join ",")&extraParams=http://multipoolminer.io" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    }
    catch {
        Write-Log -Level Warn "CryptoCompare is down. "
    }
    if ($NewRates.BTC.BTC -eq 1) {$Rates = $NewRates}
    if ($Rates.BTC.BTC -ne 1) {
        $Rates = [PSCustomObject]@{BTC = [PSCustomObject]@{BTC = [Double]1}}
    }
    $API.Balances = $Balances #Give API access to the pool balances
    $API.Rates = $Rates #Give API access to the exchange rates

    #Retrieve collected pool data
    $NewPools = @()
    if ($NewPools_Jobs) {
        if ($NewPools_Jobs | Where-Object State -NE "Completed") {Write-Log "Waiting for pool information. "}
        $NewPools = @($NewPools_Jobs | Wait-Job | Receive-Job | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru})
        $NewPools_Jobs | Remove-Job
        $NewPools_Jobs = $null
    }
    $NewPools | ForEach-Object {
        $_.Price = [Double]($_.Price * $Config.Pools.$($_.Name).PricePenaltyFactor)
        $_.StablePrice = [Double]($_.StablePrice * $Config.Pools.$($_.Name).PricePenaltyFactor)
    }
    $API.NewPools = $NewPools #Give API access to the current running configuration

    # This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    # since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    if (($Config | ConvertTo-Json -Compress -Depth 10) -ne ($OldConfig | ConvertTo-Json -Compress -Depth 10)) {$AllPools = $null}
    $AllPools = @($NewPools) + @(Compare-Object @($NewPools | Select-Object -ExpandProperty Name -Unique) @($AllPools | Select-Object -ExpandProperty Name -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$AllPools | Where-Object Name -EQ $_}) | 
        Where-Object {$Config.PoolName.Count -eq 0 -or (Compare-Object $Config.PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} |
        Where-Object {$Config.ExcludePoolName.Count -eq 0 -or (Compare-Object $Config.ExcludePoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} |
        Where-Object {$Config.Algorithm.Count -eq 0 -or (Compare-Object @($Config.Algorithm | Select-Object) @($_.Algorithm, ($_.Algorithm -split "-" | Select-Object -Index 0) | Select-Object -Unique) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$Config.ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.ExcludeAlgorithm | Select-Object) @($_.Algorithm, ($_.Algorithm -split "-" | Select-Object -Index 0) | Select-Object -Unique)  -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        Where-Object {$Config.Pools.$($_.Name).ExcludeAlgorithm.Count -eq 0 -or (Compare-Object @($Config.Pools.$($_.Name).ExcludeAlgorithm | Select-Object) @($_.Algorithm, ($_.Algorithm -split "-" | Select-Object -Index 0) | Select-Object -Unique)  -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        Where-Object {$Config.CoinName.Count -eq 0 -or (Compare-Object @($Config.CoinName | Select-Object) @($_.CoinName) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$Config.Pools.$($_.Name).CoinName.Count -eq 0 -or (Compare-Object @($Config.Pools.$($_.Name).CoinName | Select-Object) @($_.CoinName) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$Config.ExcludeCoinName.Count -eq 0 -or (Compare-Object @($Config.ExcludeCoinName | Select-Object) @($_.CoinName) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        Where-Object {$Config.Pools.$($_.Name).ExcludeCoinName.Count -eq 0 -or (Compare-Object @($Config.Pools.$($_.Name).ExcludeCoinName | Select-Object) @($_.CoinName) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        Where-Object {$Config.MiningCurrency.Count -eq 0 -or (Compare-Object @($Config.MiningCurrency | Select-Object) @($_.MiningCurrency) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$Config.Pools.$($_.Name).MiningCurrency.Count -eq 0 -or (Compare-Object @($Config.Pools.$($_.Name).MiningCurrency | Select-Object) @($_.MiningCurrency) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$Config.ExcludeMiningCurrency.Count -eq 0 -or (Compare-Object @($Config.ExcludeMiningCurrency | Select-Object) @($_.MiningCurrency) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        Where-Object {$Config.Pools.$($_.Name).ExcludeMiningCurrency.Count -eq 0 -or (Compare-Object @($Config.Pools.$($_.Name).ExcludeMiningCurrency | Select-Object) @($_.MiningCurrency) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | Sort-Object Algorithm
    $API.AllPools = $AllPools #Give API access to the current running configuration
    if ($AllPools.Count -eq 0) {
        Write-Log -Level Warn "No pools available. "
        while ((Get-Date).ToUniversalTime() -lt $StatEnd) {Start-Sleep 10}
        continue
    }

    #Apply watchdog to pools
    $AllPools = @(
        $AllPools | Where-Object {
            $Pool = $_
            $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
            ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
        }
    )

    #Update the active pools
    Write-Log "Selecting best pool for each algorithm. "
    $Pools = [PSCustomObject]@{}
    $AllPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($AllPools | Where-Object Algorithm -EQ $_ | Sort-Object -Descending {$Config.PoolName.Count -eq 0 -or (Compare-Object $Config.PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}, {($Timer - $_.Updated).TotalMinutes -le ($SyncWindow * $Strikes)}, {$_.StablePrice * (1 - $_.MarginOfError)}, {$_.Region -EQ $Config.Region}, {$_.SSL -EQ $Config.SSL} | Select-Object -First 1)}
    if (($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_.Name} | Select-Object -Unique | ForEach-Object {$AllPools | Where-Object Name -EQ $_ | Measure-Object Updated -Maximum | Select-Object -ExpandProperty Maximum} | Measure-Object -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes) -gt $SyncWindow) {
        Write-Log -Level Warn "Pool prices are out of sync ($([Int]($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_} | Measure-Object Updated -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes)) minutes). "
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Bias ($Pools.$_.StablePrice * (1 - ($Pools.$_.MarginOfError * $(if ($Pools.$_.PayoutScheme -eq "PPLNS") {$Config.SwitchingPrevention} else {1}) * (1 - $Pools.$_.Fee) * [Math]::Pow($DecayBase, $DecayExponent)))) -Force}
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Unbias ($Pools.$_.StablePrice * (1 - $Pools.$_.Fee)) -Force}
    }
    else {
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Bias ($Pools.$_.Price * (1 - ($Pools.$_.MarginOfError * $(if ($Pools.$_.PayoutScheme -eq "PPLNS") {$Config.SwitchingPrevention} else {1}) * (1 - $Pools.$_.Fee) * [Math]::Pow($DecayBase, $DecayExponent)))) -Force}
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Unbias ($Pools.$_.Price * (1 - $Pools.$_.Fee)) -Force}
    }
    $API.Pools = $Pools #Give API access to the pools information

    #Load the stats
    Write-Log "Loading saved statistics. "
    $Stats = Get-Stat
    $API.Stats = $Stats #Give API access to the current stats

    #Load information about the miners
    #Messy...?
    Write-Log "Getting miner information. "
    # Get all the miners, get just the .Content property and add the name, select only the ones that match our $Config.DeviceName (CPU, AMD, NVIDIA) or all of them if type is unset,
    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Config.MinerName, if specified, and don't match $Config.ExcludeMinerName
    $AllMiners = @(
        if (Test-Path "MinersLegacy" -PathType Container -ErrorAction Ignore) {
            #Strip Model information from devices -> will create only one miner instance
            if ($Config.CreateMinerInstancePerDeviceModel) {$DevicesTmp = $Devices} else {$DevicesTmp = $Devices | ConvertTo-Json -Depth 10 | ConvertFrom-Json; $DevicesTmp | ForEach-Object {$_.Model = ""}}
            Get-ChildItemContent "MinersLegacy" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config; Devices = $DevicesTmp} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru -Force} | 
                ForEach-Object {if (-not $_.DeviceName) {$_ | Add-Member DeviceName (Get-Device $_.Type).Name -Force}; $_} | #for backward compatibility
                ForEach-Object {if (-not $_.IntervalMultiplier) {$_ | Add-Member IntervalMultiplier ([Math]::Max(1, $_.BenchmarkIntervals)) -Force}; $_} | #for backward compatibility
                Where-Object {$_.DeviceName} | #filter miners for non-present hardware
                Where-Object {$UnprofitableAlgorithms -notcontains (($_.HashRates.PSObject.Properties.Name | Select-Object -Index 0) -replace '-NHMP'<#temp fix#> -replace 'NiceHash'<#temp fix#>)} | #filter unprofitable algorithms, allow them as secondary algo
                Where-Object {-not $Config.SingleAlgoMining -or $_.HashRates.PSObject.Properties.Name.Count -EQ 1} | #filter dual algo miners
                Where-Object {(Compare-Object @($Devices.Name | Select-Object) @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
                Where-Object {(Compare-Object $Pools.PSObject.Properties.Name $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
                Where-Object {$Config.MinerName.Count -eq 0 -or (Compare-Object $Config.MinerName ($_.Name -split "-" | Select-Object -Index 0) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
                Where-Object {$Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object $Config.ExcludeMinerName ($_.Name -split "-" | Select-Object -Index 0) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}
        }
    )

    Write-Log "Calculating profit for each miner. "
    $AllMiners | ForEach-Object {
        $Miner = $_

        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_Fees = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Profits = [PSCustomObject]@{}
        $Miner_Profits_Comparison = [PSCustomObject]@{}
        $Miner_Profits_MarginOfError = [PSCustomObject]@{}
        $Miner_Profits_Bias = [PSCustomObject]@{}
        $Miner_Profits_Unbias = [PSCustomObject]@{}

        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object { #temp fix, must use 'PSObject.Properties' to preserve order
            $Miner_HashRates | Add-Member $_ ([Double]$Miner.HashRates.$_) 
            $Miner_Fees | Add-Member $_ ([Double]$Miner.Fees.$_)
            $Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Pools_Comparison | Add-Member $_ ([PSCustomObject]$Pools.$_)
            if ($Config.IgnoreCosts) {
                $Miner_Profits | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price)
                $Miner_Profits_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice)
                $Miner_Profits_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Bias)
                $Miner_Profits_Unbias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Unbias)
            }
            else {
                $Miner_Profits | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price * (1 - $Miner.Fees.$_))
                $Miner_Profits_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice * (1 - $Miner.Fees.$_))
                $Miner_Profits_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Bias * (1 - $Miner.Fees.$_))
                $Miner_Profits_Unbias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Unbias * (1 - $Miner.Fees.$_))
            }
        }

        $Miner_Profit = [Double]($Miner_Profits.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Comparison = [Double]($Miner_Profits_Comparison.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Bias = [Double]($Miner_Profits_Bias.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Unbias = [Double]($Miner_Profits_Unbias.PSObject.Properties.Value | Measure-Object -Sum).Sum

        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            $Miner_Profits_MarginOfError | Add-Member $_ ([Double]$Pools.$_.MarginOfError * (& {if ($Miner_Profit) {([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice) / $Miner_Profit}else {1}}))
        }

        $Miner_Profit_MarginOfError = [Double]($Miner_Profits_MarginOfError.PSObject.Properties.Value | Measure-Object -Sum).Sum

        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            if (-not [String]$Miner.HashRates.$_) {
                $Miner_HashRates.$_ = $null
                $Miner_Profits.$_ = $null
                $Miner_Profits_Comparison.$_ = $null
                $Miner_Profits_Bias.$_ = $null
                $Miner_Profits_Unbias.$_ = $null
                $Miner_Profit = $null
                $Miner_Profit_Comparison = $null
                $Miner_Profits_MarginOfError = $null
                $Miner_Profit_Bias = $null
                $Miner_Profit_Unbias = $null
            }
        }

        $Miner | Add-Member HashRates $Miner_HashRates -Force
        $Miner | Add-Member Fees $Miner_Fees -Force

        $Miner | Add-Member Pools $Miner_Pools
        $Miner | Add-Member Profits $Miner_Profits
        $Miner | Add-Member Profits_Comparison $Miner_Profits_Comparison
        $Miner | Add-Member Profits_Bias $Miner_Profits_Bias
        $Miner | Add-Member Profits_Unbias $Miner_Profits_Unbias
        $Miner | Add-Member Profit $Miner_Profit
        $Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
        $Miner | Add-Member Profit_MarginOfError $Miner_Profit_MarginOfError
        $Miner | Add-Member Profit_Bias $Miner_Profit_Bias
        $Miner | Add-Member Profit_Unbias $Miner_Profit_Unbias

        $Miner | Add-Member DeviceName @($Miner.DeviceName | Select-Object -Unique | Sort-Object) -Force

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if ($Miner.Arguments -isnot [String]) {$Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress}

        if (-not $Miner.API) {$Miner | Add-Member API "Miner" -Force}
    }
    $Miners = @($AllMiners | Where-Object {(Test-Path $_.Path -PathType Leaf -ErrorAction Ignore) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath -PathType Leaf -ErrorAction Ignore))})
    $API.Miners = $Miners #Give API access to the miners information

    #Get miners needing benchmarking
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark = @($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null})

    if ($Miners.Count -ne $AllMiners.Count -and $Downloader.State -ne "Running") {
        Write-Log -Level Warn "Some miners binaries are missing, starting downloader. "
        $Downloader = Start-Job -Name Downloader -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList (@($AllMiners | Where-Object {$_.PrerequisitePath -and -not (Test-Path $_.PrerequisitePath -PathType Leaf -ErrorAction Ignore)} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}) + @($AllMiners | Where-Object {-not (Test-Path $_.Path -PathType Leaf -ErrorAction Ignore)} | Select-Object URI, Path, @{name = "Searchable"; expression = {$Miner = $_; ($AllMiners | Where-Object {(Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI}).Count -eq 0}}) | Select-Object * -Unique) -FilePath .\Downloader.ps1
    }

    #Open firewall ports for all miners
    #temp fix, needs removing from loop as it requires admin rights
    if (Get-Command "Get-MpPreference" -ErrorAction Ignore) {
        if ((Get-Command "Get-MpComputerStatus" -ErrorAction Ignore) -and (Get-MpComputerStatus -ErrorAction Ignore)) {
            if (Get-Command "Get-NetFirewallRule" -ErrorAction Ignore) {
                if ($null -eq $MinerFirewalls) {$MinerFirewalls = Get-NetFirewallApplicationFilter | Select-Object -ExpandProperty Program}
                if (@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ "=>") {
                    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'; ('$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Compress)' | ConvertFrom-Json) | ForEach {New-NetFirewallRule -DisplayName 'MultiPoolMiner' -Program `$_}" -replace '"', '\"') -Verb runAs
                    $MinerFirewalls = $null
                }
            }
        }
    }

    #Apply watchdog to miners
    $Miners = @(
        $Miners | Where-Object {
            $Miner = $_
            $Miner_WatchdogTimers = $WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval * $Miner.IntervalMultiplier) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
            ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
        }
    )

    #Use only use fastest miner per algo and device. E.g. if there are several miners available to mine the same algo, only the fastest of them will ever be used, the slower ones will also be hidden in the summary screen
    if ($Config.UseFastestMinerPerAlgoOnly) {
        $Miners = @($Miners | Where-Object {($MinersNeedingBenchmark.DeviceName | Select-Object -Unique) -notcontains $_.DeviceName} | Sort-Object -Descending {"$($_.DeviceName -join '')$(($_.HashRates.PSObject.Properties.Name | ForEach-Object {$_ -split "-" | Select-Object -Index 0}) -join '')"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, Profits_Bias, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$(($_.HashRates.PSObject.Properties.Name | ForEach-Object {$_ -split "-" | Select-Object -Index 0}) -join '')"} | ForEach-Object {$_.Group[0]}) + @($Miners | Where-Object {($MinersNeedingBenchmark.DeviceName | Select-Object -Unique) -contains $_.DeviceName})
    }
    $API.FastestMiners = $Miners #Give API access to the fastest miners information

    #Update the active miners
    if ($Miners.Count -eq 0) {
        Write-Log -Level Warn "No miners available. "
        while ((Get-Date).ToUniversalTime() -lt $StatEnd) {Start-Sleep 10}
        continue
    }

    $ActiveMiners | ForEach-Object {
        $_.Profit = 0
        $_.Profit_Comparison = 0
        $_.Profit_MarginOfError = 0
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
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }
        if ($ActiveMiner) {
            $ActiveMiner.DeviceName = $Miner.DeviceName
            $ActiveMiner.Profit = $Miner.Profit
            $ActiveMiner.Profit_Comparison = $Miner.Profit_Comparison
            $ActiveMiner.Profit_MarginOfError = $Miner.Profit_MarginOfError
            $ActiveMiner.Profit_Bias = $Miner.Profit_Bias
            $ActiveMiner.Profit_Unbias = $Miner.Profit_Unbias
            $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
            $ActiveMiner.ShowMinerWindow = $Config.ShowMinerWindow
        }
        else {
            $ActiveMiners += New-Object $Miner.API -Property @{
                Name                 = $Miner.Name
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                API                  = $Miner.API
                Port                 = $Miner.Port
                Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
                DeviceName           = $Miner.DeviceName
                Profit               = $Miner.Profit
                Profit_Comparison    = $Miner.Profit_Comparison
                Profit_MarginOfError = $Miner.Profit_MarginOfError
                Profit_Bias          = $Miner.Profit_Bias
                Profit_Unbias        = $Miner.Profit_Unbias
                Speed                = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
                Speed_Live           = 0
                Best                 = $false
                Best_Comparison      = $false
                New                  = $false
                Intervals            = @()
                Pool                 = [Array]$Miner.Pools.PSObject.Properties.Value.Name #temp fix, must use 'PSObject.Properties' to preserve order
                ShowMinerWindow      = $Config.ShowMinerWindow
                IntervalMultiplier    = $Miner.IntervalMultiplier
            }
        }
    }

    $ActiveMiners | Where-Object {$_.GetStatus() -EQ "Running"} | ForEach-Object {$_.Profit_Bias = $_.Profit_Unbias} #Don't penalize active miners
    $API.RunningMiners = @($ActiveMiners | Where-Object Best) #Update API miner information
    $API.ActiveMiners = $ActiveMiners #Update API miner information

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Profit -ne 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.Profit_Bias}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Intervals.Count}, {$_.IntervalMultiplier} | Select-Object -First 1)}
    $BestMiners_Comparison = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Profit -ne 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.Profit_Comparison}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Intervals.Count}, {$_.IntervalMultiplier} | Select-Object -First 1)}
    $Miners_Device_Combos = (Get-Combination ($ActiveMiners | Select-Object DeviceName -Unique) | Where-Object {(Compare-Object ($_.Combination | Select-Object -ExpandProperty DeviceName -Unique) ($_.Combination | Select-Object -ExpandProperty DeviceName) | Measure-Object).Count -eq 0})
    $BestMiners_Combos = $Miners_Device_Combos | ForEach-Object {
        $Miner_Device_Combo = $_.Combination
        [PSCustomObject]@{
            Combination = $Miner_Device_Combo | ForEach-Object {
                $Miner_Device_Count = $_.DeviceName.Count
                [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object {[Regex]::Escape($_)}) -join '|') + ")$"
                $BestMiners | Where-Object {([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
            }
        }
    }
    $BestMiners_Combos_Comparison = $Miners_Device_Combos | ForEach-Object {
        $Miner_Device_Combo = $_.Combination
        [PSCustomObject]@{
            Combination = $Miner_Device_Combo | ForEach-Object {
                $Miner_Device_Count = $_.DeviceName.Count
                [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object {[Regex]::Escape($_)}) -join '|') + ")$"
                $BestMiners_Comparison | Where-Object {([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
            }
        }
    }

    $BestMiners_Combo = $BestMiners_Combos | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Bias -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination
    $BestMiners_Combo_Comparison = $BestMiners_Combos_Comparison | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Comparison -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination

    #Check for failed miner
    $ActiveMiners | Where-Object Best | Where-Object {$_.GetStatus() -ne "Running"} | ForEach-Object {
        $_.SetStatus("Failed")
        Write-Log -Level Error "Miner ($($_.Name) {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP'<#temp fix#> -replace 'NiceHash'<#temp fix#>)@$($Pools.$_.Name)"}) -join "; ")}) has failed. "
    }
    $API.RunningMiners = @($ActiveMiners | Where-Object Best) #Update API miner information
    $API.FailedMiners = @($ActiveMiners | Where-Object {$_.GetStatus() -eq "Failed"}) #Update API miner information

    if ($ActiveMiners.Count -eq 1) {
        $BestMiners_Combo_Comparison = $BestMiners_Combo = @($ActiveMiners)
    }

    $BestMiners_Combo | ForEach-Object {$_.Best = $true}
    $BestMiners_Combo_Comparison | ForEach-Object {$_.Best_Comparison = $true}

    #Stop miners in the active list depending on if they are the most profitable
    $ActiveMiners | Where-Object {$_.GetActivateCount()} | Where-Object {$_.Best -EQ $false -or ($Config.ShowMinerWindow -ne $OldConfig.ShowMinerWindow)} | ForEach-Object {
        $Miner = $_
        if ($Miner.GetStatus() -eq "Running") {
            Write-Log "Stopping miner (($($Miner.Name) {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP'<#temp fix#> -replace 'NiceHash'<#temp fix#>)@$($Pools.$_.Name)"}) -join "; ")}). "
            $Miner.SetStatus("Idle")
            if ($Miner.ProcessId -and -not ($ActiveMiners | Where-Object {$_.Best -and $_.API -EQ $Miner.API})) {Stop-Process -Id $Miner.ProcessId -Force -ErrorAction Ignore} #temp fix

            #Remove watchdog timer
            $Miner_Name = $Miner.Name
            $Miner_IntervalMultiplier = $Miner.IntervalMultiplier
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($WatchdogTimer) {
                    if ($WatchdogTimer.Kicked -lt $Timer.AddSeconds( - $WatchdogInterval * $Miner_IntervalMultiplier)) {
                        $Miner.SetStatus("Failed")
                        Write-Log -Level Warn "Watchdog: Miner ($Miner_Name {$(($Miner.Algorithm | ForEach-Object {"$($_ -replace '-NHMP'<#temp fix#> -replace 'NiceHash'<#temp fix#>)@$($Pools.$_.Name)"}) -join "; ")}) temporarily disabled. "
                    }
                    else {
                        $WatchdogTimers = $WatchdogTimers -notmatch $WatchdogTimer
                    }
                }
            }
        }
    }
    $API.WatchdogTimers = $WatchdogTimers #Give API access to WatchdogTimers information
    Start-Sleep $Config.Delay #Wait to prevent BSOD
    if ($ActiveMiners | ForEach-Object {$_.GetProcessNames()}) {Get-Process -Name @($ActiveMiners | ForEach-Object {$_.GetProcessNames()} | Select-Object) -ErrorAction Ignore | Select-Object -ExpandProperty ProcessName | Compare-Object @($ActiveMiners | Where-Object Best | Where-Object {$_.GetStatus() -eq "Running"} | ForEach-Object {$_.GetProcessNames()} | Select-Object) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | Select-Object -Unique | ForEach-Object {Stop-Process -Name $_ -Force -ErrorAction Ignore}} #Kill stray miners

    #Start miners in the active list depending on if they are the most profitable
    $ActiveMiners | Where-Object Best | ForEach-Object {
        $Miner_Name = $_.Name
        if ($_.GetStatus() -ne "Running") {
            Write-Log "Starting miner ($Miner_Name {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP'<#temp fix#> -replace 'NiceHash'<#temp fix#>)@$($Pools.$_.Name)"}) -join "; ")}). "
            Write-Log -Level Verbose $_.GetCommandLine().Replace("$(Convert-Path '.\')\", "")
            $_.SetStatus("Running")
            $_.Intervals = @()

            #Add watchdog timer
            if ($Config.Watchdog -and $_.Profit -ne $null) {
                $_.Algorithm | ForEach-Object {
                    $Miner_Algorithm = $_
                    $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                    if (-not $WatchdogTimer) {
                        $WatchdogTimers += [PSCustomObject]@{
                            MinerName = $Miner_Name
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
        if ($_.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner_Name)_$($_)_HashRate")}) {
            Write-Log -Level Warn "Benchmarking miner ($Miner_Name {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP'<#temp fix#> -replace 'NiceHash'<#temp fix#>)@$($Pools.$_.Name)"}) -join "; ")})) [Attempt $($_.GetActivateCount()) of max. $Strikes]. "
        }
    }
    $API.RunningMiners = @($ActiveMiners | Where-Object Best) #Update API miner information
    $API.WatchdogTimers = $WatchdogTimers #Give API access to WatchdogTimers information

    Clear-Host

    #Display mining information
    $Miners | Where-Object {$_.Profit -ge 1E-6 -or $_.Profit -eq $null} | Sort-Object DeviceName, @{Expression = "Profit_Bias"; Descending = $True}, @{Expression = {$_.HashRates.PSObject.Properties.Name}} | Format-Table -GroupBy @{Name = "Device"; Expression = "DeviceName"} (
        @{Label = "Miner[Fee]"; Expression = {"$($_.Name)$(($_.Fees.PSObject.Properties.Value | ForEach-Object {"[{0:P2}]" -f [Double]$_}) -join '')"}}, 
        @{Label = "Algorithm"; Expression = {$_.HashRates.PSObject.Properties.Name -replace "-NHMP"<#temp fix#> -replace "NiceHash"<#temp fix#>}}, 
        @{Label = "Speed"; Expression = {$Miner = $_; $_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"}else {$(if ($ActiveMiners | Where-Object {$_.Best -eq $True -and $_.Arguments -EQ $Miner.Arguments}) {"Benchmark in progress"} else {"Benchmark pending"})}}}; Align = 'right'}, 
        @{Label = "$($Config.Currency | Select-Object -Index 0)/Day"; Expression = {if ($_.Profit) {ConvertTo-LocalCurrency $($_.Profit) $($Rates.BTC.$($Config.Currency | Select-Object -Index 0)) -Offset 2} else {"Unknown"}}; Align = "right"}, 
        @{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"{0:P0}" -f [Double](1 - $_.MarginOfError)}}; Align = 'right'}, 
        @{Label = "$($Config.Currency | Select-Object -Index 0)/GH/Day"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$(ConvertTo-LocalCurrency $($_.Price * 1000000000) $($Rates.BTC.$($Config.Currency | Select-Object -Index 0)) -Offset 2)"}}; Align = "right"}, 
        @{Label = "Pool[Fee]"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.CoinName) {"$($_.Name)-$($_.CoinName)$("[{0:P2}]" -f [Double]$_.Fee)"}else {"$($_.Name)$("[{0:P2}]" -f [Double]$_.Fee)"}}}}
    ) | Out-Host

    #Display benchmarking progress
    if ($MinersNeedingBenchmark.count -gt 0) {
        Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmark.count) miner$(if ($MinersNeedingBenchmark.count -gt 1){'s'}) left to complete benchmark."
    }

    #Display active miners list
    $ActiveMiners | Where-Object {$_.GetActivateCount()} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} (
        @{Label = "Last Speed"; Expression = {$_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.GetActiveTime()}}, 
        @{Label = "Launched"; Expression = {Switch ($_.GetActivateCount()) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
        @{Label = "Miner"; Expression = {$_.Name}},
        @{Label = "Command"; Expression = {$_.GetCommandLine().Replace("$(Convert-Path '.\')\", "")}}
    ) | Out-Host

    #Display watchdog timers
    $WatchdogTimers | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset) | Format-Table -Wrap (
        @{Label = "Miner"; Expression = {$_.MinerName}}, 
        @{Label = "Pool"; Expression = {$_.PoolName}}, 
        @{Label = "Algorithm"; Expression = {$_.Algorithm}}, 
        @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'}
    ) | Out-Host

    #Display profit comparison
    if (-not ($BestMiners_Combo | Where-Object Profit -EQ $null) -and $Downloader.State -eq "Running") {$Downloader | Wait-Job -Timeout 10 | Out-Null}
    if (-not ($BestMiners_Combo | Where-Object Profit -EQ $null) -and $Downloader.State -ne "Running") {
        $MinerComparisons = 
        [PSCustomObject]@{"Miner" = "MultiPoolMiner"}, 
        [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object {"$($_.Name)-$($_.Algorithm -join '/')"}}

        $BestMiners_Combo_Stat = Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure-Object Profit -Sum).Sum -Duration $StatSpan

        $MinerComparisons_Profit = $BestMiners_Combo_Stat.Week, ($BestMiners_Combo_Comparison | Measure-Object Profit_Comparison -Sum).Sum

        $MinerComparisons_MarginOfError = $BestMiners_Combo_Stat.Week_Fluctuation, ($BestMiners_Combo_Comparison | ForEach-Object {$_.Profit_MarginOfError * (& {if ($MinerComparisons_Profit[1]) {$_.Profit_Comparison / $MinerComparisons_Profit[1]}else {1}})} | Measure-Object -Sum).Sum

        $Config.Currency | Where-Object {$Rates.BTC.$_} | ForEach-Object {
            $MinerComparisons[0] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[0] * $Rates.BTC.$_), $MinerComparisons_MarginOfError[0], (($MinerComparisons_Profit[0] * $Rates.BTC.$_) / (1 + $MinerComparisons_MarginOfError[0])), (($MinerComparisons_Profit[0] * $Rates.BTC.$_) * (1 + $MinerComparisons_MarginOfError[0])))
            $MinerComparisons[1] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[1] * $Rates.BTC.$_), $MinerComparisons_MarginOfError[1], (($MinerComparisons_Profit[1] * $Rates.BTC.$_) / (1 + $MinerComparisons_MarginOfError[1])), (($MinerComparisons_Profit[1] * $Rates.BTC.$_) * (1 + $MinerComparisons_MarginOfError[1])))
        }

        if ([Math]::Round(($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1], 2) -gt 0) {
            $MinerComparisons_Range = ($MinerComparisons_MarginOfError | Measure-Object -Average | Select-Object -ExpandProperty Average), (($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1]) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
            Write-Host -BackgroundColor Yellow -ForegroundColor Black "MultiPoolMiner is between $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])-$MinerComparisons_Range)*100)))% and $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])+$MinerComparisons_Range)*100)))% more profitable than the fastest miner: "
        }

        $MinerComparisons | Out-Host
    }

    #Display pool balances
    if ($Balances) {
        Write-Host "Pool Balances: $(($Config.Currency | Where-Object {$Rates.BTC.$_} | ForEach-Object {"$(($Balances | Where-Object {$Rates.($_.Currency).BTC} | ForEach-Object {$_.Total * $Rates.($_.Currency).BTC} | Measure-Object -Sum).Sum * $Rates.BTC.$_) $($_)"}) -join " = ")"
    }

    #Display exchange rates
    Write-Host "Exchange Rates: $(($Config.Currency | Where-Object {$Rates.BTC.$_} | ForEach-Object {"$($Rates.BTC.$_) $($_)"}) -join " = ")"

    Write-Log "Interval will end in approximately $([Math]::Max(0, [Math]::Ceiling((($StatEnd - (Get-Date).ToUniversalTime()).TotalSeconds) / 10) * 10)) seconds. "
    while ((Get-Date).ToUniversalTime() -lt $StatEnd) {Start-Sleep 10}
    Write-Log "Interval overrun by approximately $([Math]::Max(0, [Math]::Floor((((Get-Date).ToUniversalTime() - $StatStart).TotalSeconds - $Config.Interval) / 10) * 10)) seconds. "
}

Write-Log "Stopping MultiPoolMiner® v$Version © 2017-$((Get-Date).Year) MultiPoolMiner.io"

#Stop the log
Stop-Transcript

exit
