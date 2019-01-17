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
    [Switch]$DisableDualMining = $false, #disables all dual mining miners
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
    [Switch]$IgnoreFees = $false, #if $true MPM will ignore miner and pool fees for its calculations (as older versions did)
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalances = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalancesExcludedPools = $false,
    [Parameter(Mandatory = $false)]
    [Switch]$ShowPoolBalancesDetails = $false,
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 999)]
    [Int]$PoolBalancesUpdateInterval = 15, #MPM will update balances every n minutes to limit pool API requests (but never more than ONCE per loop). Allowed values 1 - 999 minutes
    [Parameter(Mandatory = $false)]
    [Switch]$CreateMinerInstancePerDeviceModel = $false, #if true MPM will create separate miner instances per device model. This will improve profitability.
    [Parameter(Mandatory = $false)]
    [Switch]$UseDeviceNameForStatsFileNaming = $false, #if true the benchmark files will be named like 'NVIDIA-CryptoDredge-2xGTX1080Ti_Lyra2RE2_HashRate'. This will keep benchmarks files valid even when the order of the cards are changed in your rig
    [Parameter(Mandatory = $false)]
    [String]$ConfigFile = ".\Config.txt", #default config file
    [Parameter(Mandatory = $false)]
    [Switch]$RemoteAPI = $false,
    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 10)]
    [Int]$HashRateSamplesPerMinute = 10, #number of hashrate samples that MPM will collect per minute (higher numbers produce more exact numbers, but use more CPU cycles and memory). Allowed values: 5 - 10
    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 300)]
    [Int]$BenchmarkInterval = 60, #seconds that MPM will have to collect hashrates when benchmarking. Allowed values: 60 - 300
    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 30)]
    [Int]$MinHashRateSamples = 10, #minumum number of hashrate samples that MPM will collect in benchmark operation (higher numbers produce more exact numbers, but will prolongue benchmarking. Allowed values: 10 - 30
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
$LastReport = $Timer
$StatEnd = $Timer
$DecayStart = $Timer
$DecayPeriod = 60 #seconds
$DecayBase = 1 - 0.1 #decimal percentage

$WatchdogTimers = @()

$ActiveMiners = @()
$RunningMiners = @()

$Rates = [PSCustomObject]@{BTC = [Double]1}

#Start the log
Start-Transcript ".\Logs\MultiPoolMiner_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

Write-Log "Starting MultiPoolMiner® v$Version © 2017-2019 MultiPoolMiner.io"

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

#Append .txt extension if no extension is given
if (-not [IO.Path]::GetExtension($ConfigFile)) {$ConfigFile = "$($ConfigFile).txt"}
$Config = [PSCustomObject]@{}
if (Test-Path $ConfigFile -PathType Leaf) {
    $Error.Clear() #Clear all errors from previous run, reduce memory
    $ConfigFile = Resolve-Path $ConfigFile
    $Config = Get-Content $ConfigFile | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $Config.VersionCompatibility) {
        Write-Log -Level Error "Config file ($ConfigFile) is not a valid MPM configuration file. Cannot continue. "
        Start-Sleep 10
        Exit
    }
    Write-Log -Level Info "Using configuration file ($ConfigFile). "
    $ConfigOld = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json #$Config = $ConfigOld does not work (https://kevinmarquette.github.io/2016-10-28-powershell-everything-you-wanted-to-know-about-pscustomobject/#objects-vs-value-types)

    #Add variables that do not have an entry in config file
    $MyInvocation.MyCommand.Parameters.Keys | Where-Object {$_ -ne "ConfigFile" -and $_ -ne "Wallet" -and (Get-Variable $_ -ErrorAction SilentlyContinue)} | ForEach-Object {
        $Config | Add-Member $_ "`$$($_)" -ErrorAction SilentlyContinue
    }

    $Config | Add-Member VersionCompatibility $VersionCompatibility -Force
    $Config | Add-Member Region (Get-Region ($Config.Region)) -Force
    $Config | Add-Member Pools ([PSCustomObject]@{}) -ErrorAction SilentlyContinue
    $Config | Add-Member Miners ([PSCustomObject]@{}) -ErrorAction SilentlyContinue
    $Config | Add-Member Wallets ([PSCustomObject]@{}) -ErrorAction SilentlyContinue
    if ($Config.Wallet) {
        $Config.Wallets | Add-Member BTC $Config.Wallet -ErrorAction SilentlyContinue
        $Config.PSObject.Properties.Remove("Wallet")
    }

    if (($Config | ConvertTo-Json -Depth 10 -Compress) -ne ($ConfigOld | ConvertTo-Json -Depth 10 -Compress)) {
        #Update existing config file
        Try {
            $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Encoding utf8 -Force
            Write-Log -Level Info "Updating config file ($ConfigFile); adding missing defaults. "
        }
        Catch {
            Write-Log -Level Error "Error updating config file ($ConfigFile). Cannot continue. "
            Start-Sleep 10
            Exit
        }
    }
}
else {
    #Create new config file: Read command line parameters except ConfigFile
    $MyInvocation.MyCommand.Parameters.Keys | Sort-Object | Where-Object {$_ -ne "ConfigFile" -and $_ -ne "Wallet"} | ForEach-Object {
        if (Get-Variable $_ -ErrorAction SilentlyContinue) {
            $Config | Add-Member $_ "`$$($_)" -ErrorAction SilentlyContinue
        }
    }

    $Config | Add-Member VersionCompatibility $VersionCompatibility
    $Config | Add-Member Pools ([PSCustomObject]@{})
    $Config | Add-Member Miners ([PSCustomObject]@{})
    $Config | Add-Member Wallets ([PSCustomObject]@{BTC = "`$Wallet"})

    $Devices = Get-Device
    if (-not $UseFastestMinerPerAlgoOnly) {
        $Config.UseFastestMinerPerAlgoOnly = $true
        Write-Log -Level Info -Message "For best profitability MPM will set 'UseFastestMinerPerAlgoOnly=true'. "
    }

    if (-not $CreateMinerInstancePerDeviceModel) {
        $Config.CreateMinerInstancePerDeviceModel = $true
        Write-Log -Level Info -Message "For best profitability MPM will set 'CreateMinerInstancePerDeviceModel=true'. "
    }

    if (-not $UseDeviceNameForStatsFileNaming) {
        $Config.UseDeviceNameForStatsFileNaming = $true
        Write-Log -Level Info -Message "For best compatibility MPM will set 'UseDeviceNameForStatsFileNaming=true'. "
    }
    Write-Log -Level Info -Message "You can change settings directly in the config file - see the README for detailed instructions. "

    Try {
        $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Encoding utf8 -Force
        $ConfigFile = Resolve-Path $ConfigFile
        Write-Log -Level Info -Message "No valid config file found. Creating new config file ($ConfigFile) using defaults. "
    }
    Catch {
        Write-Log -Level Error "Error writing config file ($($ConfigFile)). Cannot continue. "
        Start-Sleep 10
        Exit
    }
}

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}
if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

#Set donation parameters
$LastDonated = $Timer.AddDays(-1).AddHours(1)
$WalletDonate = ((@("1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb") * 3) + (@("16Qf1mEk5x2WjJ1HhfnvPnqQEi2fvCeity") * 2) + (@("1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF") * 2))[(Get-Random -Minimum 0 -Maximum ((3 + 2 + 2) - 1))]
$UserNameDonate = ((@("aaronsace") * 3) + (@("grantemsley") * 2) + (@("uselessguru") * 2))[(Get-Random -Minimum 0 -Maximum ((3 + 2 + 2) - 1))]
$WorkerNameDonate = "multipoolminer"

while ($true) {
    $Error.Clear() # Clear all errors from previous run, reduce memory
    $ConfigBackup = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    #Add existing variables to $Parameters so they are available in psm1
    $Config_Parameters = @{}
    $Config = [PSCustomObject]@{}
    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    if (-not $Config.VersionCompatibility) {
        Write-Log -Level Error "Config file ($ConfigFile) is not a valid MPM configuration file. Cannot continue. "
        Start-Sleep 10
        Exit
    }
    elseif ([System.Version]$Config.VersionCompatibility -lt [System.Version]$VersionCompatibility) {
        Write-Log -Level Error "Config file ($ConfigFile) is not compatible with this version of MPM (min. required config file version is $VersionCompatibility). Cannot continue. "
        Start-Sleep 10
        Exit
    }
    $ConfigBackup | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
        if ($ConfigBackup.$_ -like "`$*") {
            #First run read values from command line
            if ((Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue).IsPresent -match ".+") {
                #Convert switch variables to proper $true/$false
                $Config_Parameters.Add($_, (Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue).IsPresent)
            }
            else {
                $Config_Parameters.Add($_, (Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue))
            }
        }
        else {
            $Config_Parameters.Add($_, $ConfigBackup.$_)
        }
    }
    $Config = [PSCustomObject]@{}
    $Config = Get-ChildItemContent $ConfigFile -Parameters $Config_Parameters | Select-Object -ExpandProperty Content

    #Initialize the API only once
    if (-not (Test-Path Variable:API)) {
        Import-Module .\API.psm1
        Start-APIServer -RemoteAPI:$Config.RemoteAPI
        $API.Version = $Version
        $API.Devices = $Devices
    }

    #Config file may not contain an entry for all supported parameters, use value from command line, or if empty use default
    $Config | Add-Member Pools ([PSCustomObject]@{}) -ErrorAction SilentlyContinue
    $Config | Add-Member Miners ([PSCustomObject]@{}) -ErrorAction SilentlyContinue
    if (-not $Config.Wallets.BTC -and $Wallet) {
        $Config.Wallets | Add-Member BTC $Wallet -Force
    }

    if (-not $Config.Wallets.BTC -and -not $Config.UserName) {
        Write-Log -Level Error "No wallet or username specified. Cannot continue. "
        Start-Sleep 10
        Exit
    }

    #For backwards compatibility, set the MinerStatusKey to $Config.Wallets.BTC if it is not specified
    if (-not $Config.MinerStatusKey -and $Config.Wallets.BTC) {$Config | Add-Member MinerStatusKey $Config.Wallets.BTC -Force}

    #Unprofitable algorithms
    if (Test-Path ".\UnprofitableAlgorithms.txt" -PathType Leaf) {$UnprofitableAlgorithms = [Array](Get-Content ".\UnprofitableAlgorithms.txt" | ConvertFrom-Json -ErrorAction SilentlyContinue | Sort-Object -Unique)} else {$UnprofitableAlgorithms = @()}

    #Need to read pools and balances file list. The pool balance query fails if the pool file does not exist and no wallet information is configured in $Config.Pools.[PoolName]
    @($(if (Test-Path "Pools" -PathType Container ) {Get-ChildItem "Pools" -File}) + $(if (Test-Path "Balances" -PathType Container) {Get-ChildItem "Balances" -File})).BaseName | Select-Object -Unique | ForEach-Object {
        #Set values if not explicitly set in pool section
        $Config.Pools | Add-Member $_ ([PSCustomObject]@{}) -ErrorAction SilentlyContinue
        $Config.Pools.($_) | Add-Member User               $Config.UserName           -ErrorAction SilentlyContinue
        $Config.Pools.($_) | Add-Member Worker             $Config.WorkerName         -ErrorAction SilentlyContinue
        $Config.Pools.($_) | Add-Member Wallets            $Config.Wallets            -ErrorAction SilentlyContinue
        $Config.Pools.($_) | Add-Member API_ID             $Config.API_ID             -ErrorAction SilentlyContinue
        $Config.Pools.($_) | Add-Member API_Key            $Config.API_Key            -ErrorAction SilentlyContinue
        $Config.Pools.($_) | Add-Member PricePenaltyFactor $Config.PricePenaltyFactor -ErrorAction SilentlyContinue
    }

    # Copy the user's config before changing anything for donation runs
    # This is used when getting pool balances so it doesn't get pool balances of the donation address instead
    $UserConfig = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json

    #Activate or deactivate donation
    if ($Config.Donate -lt 10) {$Config.Donate = 10}
    if ($Timer.AddDays(-1) -ge $LastDonated.AddSeconds(59)) {$LastDonated = $Timer}
    if ($Timer.AddDays(-1).AddMinutes($Config.Donate) -ge $LastDonated) {
        if ($WalletDonate -and $UserNameDonate -and $WorkerNameDonate) {
            Write-Log "Donation run, mining to donation address for the next $(($LastDonated - ($Timer.AddDays(-1))).Minutes +1) minutes. Note: MPM will use ALL available pools. "
            (Get-ChildItem "Pools" -File).BaseName | ForEach-Object {
                $Config.Pools | Add-Member $_ (
                    [PSCustomObject]@{
                        User               = $UserNameDonate
                        Worker             = $WorkerNameDonate
                        Wallets            = [PSCustomObject]@{BTC = $WalletDonate}
                        PricePenaltyFactor = $Config.Pools.$($_).PricePenaltyFactor
                    }
                ) -Force
            }
            $Config | Add-Member ExcludePoolName @() -Force
        }
        else {
            Write-Log -Level Warn "Donation information is missing. "
        }
    }
    else {
        Write-Log ("Mining for you. Donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($LastDonated.AddDays(1) - ($Timer.AddMinutes($Config.Donate))))
    }

    #Give API access to the current running configuration
    $API.Config = $Config

    #Load information about the devices
    $Devices = @(Get-Device -Name @($Config.DeviceName) -ExcludeName @($Config.ExcludeDeviceName | Select-Object) -Refresh:([Boolean]((Compare-Object @($Config.DeviceName | Select-Object) @($ConfigBackup.DeviceName | Select-Object)) -or (Compare-Object @($Config.ExcludeDeviceName | Select-Object) @($ConfigBackup.ExcludeDeviceName | Select-Object)))))

    if (-not $Devices.Count) {
        Write-Log -Level Warn "No mining devices found. "
        if ($Downloader) {$Downloader | Receive-Job}
        Start-Sleep $Config.Interval
        continue
    } 

    #Give API access to the device information
    $API.Devices = $Devices

    #Clear pool cache if the pool configuration has changed
    if ((($ConfigBackup.Pools | ConvertTo-Json -Compress -Depth 10) -ne ($Config.Pools | ConvertTo-Json -Compress -Depth 10)) -or ($ConfigBackup.PoolName -ne $Config.PoolName) -or ($ConfigBackup.ExcludePoolName -ne $Config.ExcludePoolName)) {$AllPools = $null}

    if ($Config.Proxy) {$PSDefaultParameterValues["*:Proxy"] = $Config.Proxy}
    else {$PSDefaultParameterValues.Remove("*:Proxy")}

    if (Test-Path "APIs" -PathType Container) {Get-ChildItem "APIs" -File | ForEach-Object {. $_.FullName}}

    $Timer = (Get-Date).ToUniversalTime()

    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Config.Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)

    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

    #Load information about the pools
    $NewPools = @()
    if ((-not $GetPoolDataJobs.Count) -and (Test-Path "Pools" -PathType Container)) {
        $GetPoolDataJobs = @()
        Write-Log "Loading pool information - this may take a minute or two. "
        Get-ChildItem "Pools" -File | Where-Object {$Config.Pools.$($_.BaseName) -and $Config.ExcludePoolName -inotcontains $_.BaseName} | Where-Object {$Config.PoolName.Count -eq 0 -or $Config.PoolName -contains $_.BaseName} | ForEach-Object {
            $Pool_Name = $_.BaseName
            $Pool_Parameters = @{StatSpan = $StatSpan}
            $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object {$Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name)}
            $GetPoolDataJobs += Start-Job -Name "GetPoolData_$($Pool_Name)" -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList $Pool_Name, "Pools\$($_.Name)", $Pool_Parameters -FilePath .\Get-PoolData.ps1
        }
    }

    #Load the stats
    Write-Log "Loading saved statistics. "
    $Stats = Get-Stat

    #Give API access to the current stats
    $API.Stats = $Stats
    
    #Update the exchange rates
    try {
        Write-Log "Updating exchange rates from Coinbase. "
        $NewRates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
        $Config.Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Rates | Add-Member $_ ([Double]$NewRates.$_) -Force}
    }
    catch {
        Write-Log -Level Warn "Coinbase is down. "
    }

    #Update the pool balances every n minute to minimize web requests or when currency settings have changed; pools usually do not update the balances in real time
    if ($NewRates -and (Test-Path "Balances" -PathType Container) -and (((Get-Date).AddMinutes(- $Config.PoolBalancesUpdateInterval) -gt $BalancesData.Updated) -and ($Config.ShowPoolBalances -or $Config.ShowPoolBalancesExcludedPools)) -or (Compare-Object $Config.Currency $ConfigBackup.Currency)) {
        Write-Log "Getting pool balances. "
        $GetPoolBalancesJob = Start-Job -Name "GetPoolBalances" -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList $UserConfig, $NewRates -FilePath .\Get-PoolBalances.ps1
    }

    #Retrieve collected pool data
    if ($GetPoolDataJobs.Count) {
        if ($GetPoolDataJobs | Where-Object State -NE "Completed") {Write-Log "Waiting for pool information. "}
        $NewPools = @(
            Get-Job | Where-Object Name -Like "GetPoolData_*" | Wait-Job | Receive-Job | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru}
        )
        Get-Job | Where-Object Name -Like "GetPoolData_*" | Remove-Job
        #Use average of last two periods for more stable values
        $GetPoolDataJobsDuration = ($GetPoolDataJobsDuration + (($GetPoolDataJobs | Measure-Object PSEndTime -Maximum).Maximum - ($GetPoolDataJobs | Measure-Object PSBeginTime -Minimum).Minimum).TotalSeconds) / 2
        $GetPoolDataJobs = @()
    }

    #Apply PricePenaltyFactor to pools
    $NewPools | ForEach-Object {
        $_.Price = [Double]($_.Price * $Config.Pools.$($_.Name).PricePenaltyFactor)
        $_.StablePrice = [Double]($_.StablePrice * $Config.Pools.$($_.Name).PricePenaltyFactor)
    }

    #Give API access to the current running configuration
    $API.NewPools = $NewPools

    # This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    # since mining is probably still working.  Then it filters out any algorithms that aren't being used.
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

    #Give API access to the current running configuration
    $API.AllPools = $AllPools

    #Apply watchdog to pools
    $AllPools = @(
        $AllPools | Where-Object {
            $Pool = $_
            $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
            ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
        }
    )

    if ($AllPools.Count -eq 0) {
        Write-Log -Level Warn "No pools available. "
        if ($Downloader) {$Downloader | Receive-Job}
        Start-Sleep $Config.Interval
        continue
    }
    $Pools = [PSCustomObject]@{}

    #Update the active pools
    Write-Log "Selecting best pool for each algorithm. "
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

    #Give API access to the pools information
    $API.Pools = $Pools

    #Load information about the miners
    #Messy...?
    Write-Log "Getting miner information. "
    # Get all the miners, get just the .Content property and add the name, select only the ones that match our $Config.DeviceName (CPU, AMD, NVIDIA) or all of them if type is unset,
    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Config.MinerName, if specified, and don't match $Config.ExcludeMinerName
    $AllMiners = @(
        if (Test-Path "MinersLegacy" -PathType Container) {
            #Strip Model information from devices -> will create only one miner instance
            if ($Config.CreateMinerInstancePerDeviceModel) {$DevicesTmp = $Devices} else {$DevicesTmp = $Devices | ConvertTo-Json -Depth 10 | ConvertFrom-Json; $DevicesTmp | ForEach-Object {$_.Model = ""}}
            Get-ChildItemContent "MinersLegacy" -Parameters @{Pools = $Pools; Stats = $Stats; Config = $Config; Devices = $DevicesTmp} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru -Force} | 
                ForEach-Object {if (-not $_.DeviceName) {$_ | Add-Member DeviceName (Get-Device $_.Type).Name -Force}; $_} | #for backward compatibility
                ForEach-Object {if (-not $_.BenchmarkIntervals) {$_ | Add-Member BenchmarkIntervals 1 -Force}; $_} | #for backward compatibility
                Where-Object {$_.DeviceName} | #filter miners for non-present hardware
                Where-Object {$UnprofitableAlgorithms -notcontains ($_.HashRates.PSObject.Properties.Name | Select-Object -Index 0)} | #filter unprofitable algorithms, allow them as secondary algo
                Where-Object {-not $Config.DisableDualMining -or $_.HashRates.PSObject.Properties.Name.Count -EQ 1} | #filter dual algo miners
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
            if ($Config.IgnoreFees) {
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
    $Miners = @($AllMiners | Where-Object {(Test-Path $_.Path -PathType Leaf) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath))})

    #Give API access to the miners information
    $API.Miners = $Miners

    #Get miners needing benchmarking
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark = @($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null})

    if ($Miners.Count -ne $AllMiners.Count -and $Downloader.State -ne "Running") {
        Write-Log -Level Warn "Some miners binaries are missing, starting downloader. "
        $Downloader = Start-Job -Name Downloader -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList (@($AllMiners | Where-Object {$_.PrerequisitePath -and -not (Test-Path $_.PrerequisitePath -PathType Leaf)} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}) + @($AllMiners | Where-Object {-not (Test-Path $_.Path)} | Select-Object URI, Path, @{name = "Searchable"; expression = {$Miner = $_; ($AllMiners | Where-Object {(Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI}).Count -eq 0}}) | Select-Object * -Unique) -FilePath .\Downloader.ps1
    }

    # Open firewall ports for all miners
    if (Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) {
        if ((Get-Command "Get-MpComputerStatus" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
            if (Get-Command "Get-NetFirewallRule" -ErrorAction SilentlyContinue) {
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
            $Miner_WatchdogTimers = $WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
            ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
        }
    )

    #Use only use fastest miner per algo and device. E.g. if there are several miners available to mine the same algo, only the fastest of them will ever be used, the slower ones will also be hidden in the summary screen
    if ($Config.UseFastestMinerPerAlgoOnly) {
        $Miners = @($Miners | Where-Object {($MinersNeedingBenchmark.DeviceName | Select-Object -Unique) -notcontains $_.DeviceName} | Sort-Object -Descending {"$($_.DeviceName -join '')$(($_.HashRates.PSObject.Properties.Name | ForEach-Object {$_ -split "-" | Select-Object -Index 0}) -join '')"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, Profits_Bias, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$(($_.HashRates.PSObject.Properties.Name | ForEach-Object {$_ -split "-" | Select-Object -Index 0}) -join '')"} | ForEach-Object {$_.Group[0]}) + @($Miners | Where-Object {($MinersNeedingBenchmark.DeviceName | Select-Object -Unique) -contains $_.DeviceName})
    }

    #Give API access to the fastest miners information
    $API.FastestMiners = $Miners

    #Update the active miners
    if ($Miners.Count -eq 0) {
        Write-Log -Level Warn "No miners available. "
        if ($Downloader) {$Downloader | Receive-Job}
        Start-Sleep ([Int]($Config.Interval / 10))
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
                Benchmarked          = 0
                Pool                 = [Array]$Miner.Pools.PSObject.Properties.Value.Name #temp fix, must use 'PSObject.Properties' to preserve order
                ShowMinerWindow      = $Config.ShowMinerWindow
                BenchmarkIntervals   = $Miner.BenchmarkIntervals
            }
        }
    }

    #Don't penalize active miners
    $ActiveMiners | Where-Object {$_.GetStatus() -EQ "Running"} | ForEach-Object {$_.Profit_Bias = $_.Profit_Unbias}

    #Update API miner information
    $API.ActiveMiners = @($ActiveMiners)

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Profit -ne 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.Profit_Bias}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {$_.BenchmarkIntervals} | Select-Object -First 1)}
    $BestMiners_Comparison = $ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0 -and $_.Profit -ne 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.Profit_Comparison}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {$_.BenchmarkIntervals} | Select-Object -First 1)}
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
    $RunningMiners | Where-Object {$_.GetStatus() -ne "Running"} | ForEach-Object {
        $_.SetStatus("Failed")
        Write-Log -Level Error "Miner ($($_.Name) {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")}) has failed. "
    }
    $API.FailedMiners = @($ActiveMiners | Where-Object {$_.GetStatus() -eq "Failed"})

    if ($ActiveMiners.Count -eq 1) {
        $BestMiners_Combo_Comparison = $BestMiners_Combo = @($ActiveMiners)
    }

    $BestMiners_Combo | ForEach-Object {$_.Best = $true}
    $BestMiners_Combo_Comparison | ForEach-Object {$_.Best_Comparison = $true}

    #Stop or start miners in the active list depending on if they are the most profitable
    $ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0} | Where-Object {$_.Best -EQ $false -or ($Config.ShowMinerWindow -ne $ConfigOld.ShowMinerWindow)} | ForEach-Object {
        $Miner = $_
        $RunningMiners = $RunningMiners | Where-Object $_ -NE $Miner 
        $Miner_Name = $_.Name
        if ($Miner.GetStatus() -eq "Running") {
            Write-Log "Stopping miner (($Miner_Name {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")}). "
            $Miner.SetStatus("Idle")
            #Close Excavator if no longer used
            if ($Miner.ProcessId -and -not ($ActiveMiners | Where-Object {$_.Best -and $_.API -EQ $Miner.API})) {Stop-Process -Id $Miner.ProcessId -Force -ErrorAction Ignore}

            #Remove watchdog timer
            $Miner_Name = $Miner.Name
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($WatchdogTimer) {
                    if ($WatchdogTimer.Kicked -lt $Timer.AddSeconds( - $WatchdogInterval)) {
                        $Miner.SetStatus("Failed")
                        Write-Log -Level Warn "Watchdog: Miner ($Miner_Name {$(($Miner.Algorithm | ForEach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")}) temporarily disabled. "
                    }
                    else {
                        $WatchdogTimers = $WatchdogTimers -notmatch $WatchdogTimer
                    }
                }
            }
        }
    }

    if ($Downloader) {$Downloader | Receive-Job}
    Start-Sleep $Config.Delay #Wait to prevent BSOD

    #Kill stray miners
    Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {$_.ExecutablePath -like "$(Get-Location)\Bin\*"} | Where-Object {$ActiveMiners.ProcessID -notcontains $_.ProcessID} | Select-Object -ExpandProperty ProcessID | ForEach-Object {Stop-Process -Id $_ -Force -ErrorAction Ignore}

    $RunningMiners = @()
    $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
        $RunningMiners += $_
        $Miner_Name = $_.Name
        if ($_.GetStatus() -ne "Running") {
            Write-Log "Starting miner ($Miner_Name {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")}). "
            Write-Log -Level Verbose $_.GetCommandLine().Replace("$(Convert-Path '.\')\", "")
            $_.SetStatus("Running")

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
            Write-Log -Level Warn "Benchmarking miner ($Miner_Name {$(($_.Algorithm | ForEach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")})$(if ($_.BenchmarkIntervals -gt 1) {" requires extended benchmark duration (Benchmarking interval $($_.Benchmarked + 1)/$($_.BenchmarkIntervals))"}) [Attempt $($_.GetActivateCount()) of max. $Strikes]. "
        }

        #Update API miner information
        $API.RunningMiners = @($RunningMiners)
    }

    Clear-Host

    #Display mining information
    $Miners | Where-Object {$_.Profit -ge 1E-6 -or $_.Profit -eq $null} | Sort-Object DeviceName, @{Expression = "Profit_Bias"; Descending = $True}, @{Expression = {$_.HashRates.PSObject.Properties.Name}} | Format-Table -GroupBy @{Name = "Device"; Expression = "DeviceName"} (
        @{Label = "Miner[Fee]"; Expression = {"$($_.Name)$(($_.Fees.PSObject.Properties.Value | ForEach-Object {"[{0:P2}]" -f [Double]$_}) -join '')"}}, 
        @{Label = "Algorithm"; Expression = {$_.HashRates.PSObject.Properties.Name -replace "-NHMP" -replace "NiceHash"}}, 
        @{Label = "Speed"; Expression = {$Miner = $_; $_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"}else {$(if ($ActiveMiners | Where-Object {$_.Best -eq $True -and $_.Arguments -EQ $Miner.Arguments}) {"Benchmark in progress"} else {"Benchmark pending"})}}}; Align = 'right'}, 
        @{Label = "$($Config.Currency | Select-Object -Index 0)/Day"; Expression = {if ($_.Profit) {ConvertTo-LocalCurrency $($_.Profit) $($Rates.$($Config.Currency | Select-Object -Index 0)) -Offset 2} else {"Unknown"}}; Align = "right"}, 
        @{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"{0:P0}" -f [Double](1 - $_.MarginOfError)}}; Align = 'right'}, 
        @{Label = "$($Config.Currency | Select-Object -Index 0)/GH/Day"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$(ConvertTo-LocalCurrency $($_.Price * 1000000000) $($Rates.$($Config.Currency | Select-Object -Index 0)) -Offset 2)"}}; Align = "right"}, 
        @{Label = "Pool[Fee]"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.CoinName) {"$($_.Name)-$($_.CoinName)$("[{0:P2}]" -f [Double]$_.Fee)"}else {"$($_.Name)$("[{0:P2}]" -f [Double]$_.Fee)"}}}}
    ) | Out-Host

    #Display benchmarking progress
    if ($MinersNeedingBenchmark.count -gt 0) {
        Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmark.count) miner$(if ($MinersNeedingBenchmark.count -gt 1){'s'}) left to complete benchmark."
    }

    #Display active miners list
    $ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} (
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
    if ($Downloader.State -eq "Running") {$Downloader | Wait-Job -Timeout 10 | Out-Null}
    if (($BestMiners_Combo | Where-Object Profit -EQ $null | Measure-Object).Count -eq 0 -and $Downloader.State -ne "Running") {
        $MinerComparisons = 
        [PSCustomObject]@{"Miner" = "MultiPoolMiner"}, 
        [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object {"$($_.Name)-$($_.Algorithm -join '/')"}}

        $BestMiners_Combo_Stat = Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure-Object Profit -Sum).Sum -Duration $StatSpan

        $MinerComparisons_Profit = $BestMiners_Combo_Stat.Week, ($BestMiners_Combo_Comparison | Measure-Object Profit_Comparison -Sum).Sum

        $MinerComparisons_MarginOfError = $BestMiners_Combo_Stat.Week_Fluctuation, ($BestMiners_Combo_Comparison | ForEach-Object {$_.Profit_MarginOfError * (& {if ($MinerComparisons_Profit[1]) {$_.Profit_Comparison / $MinerComparisons_Profit[1]}else {1}})} | Measure-Object -Sum).Sum

        $Config.Currency | Where-Object {$Rates.$_} | ForEach-Object {
            $MinerComparisons[0] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[0] * $Rates.$_), $MinerComparisons_MarginOfError[0], (($MinerComparisons_Profit[0] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[0])), (($MinerComparisons_Profit[0] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[0])))
            $MinerComparisons[1] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[1] * $Rates.$_), $MinerComparisons_MarginOfError[1], (($MinerComparisons_Profit[1] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[1])), (($MinerComparisons_Profit[1] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[1])))
        }

        if ([Math]::Round(($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1], 2) -gt 0) {
            $MinerComparisons_Range = ($MinerComparisons_MarginOfError | Measure-Object -Average | Select-Object -ExpandProperty Average), (($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1]) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
            Write-Host -BackgroundColor Yellow -ForegroundColor Black "MultiPoolMiner is between $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])-$MinerComparisons_Range)*100)))% and $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])+$MinerComparisons_Range)*100)))% more profitable than the fastest miner: "
        }

        $MinerComparisons | Out-Host
    }

    if ($GetPoolBalancesJob) {
        $BalancesData = $GetPoolBalancesJob | Wait-Job | Receive-Job
        $GetPoolBalancesJob = $null
    }

    if ($BalancesData.Balances) {
        #Give API access to the pool balances
        $API.BalancesData = $BalancesData

        #Display pool balances, formatting it to show all the user specified currencies
        if ($Config.ShowPoolBalances -or $Config.ShowPoolBalancesExcludedPools) {
            Write-Host "Pool Balances (last updated $($BalancesData.Updated.ToString())):"
            $Columns = @()
            $ColumnFormat = [Array]@{Name = "Name$(' ' * (($BalancesData.Balances.Name | Measure-Object Length -Maximum | Select-Object -ExpandProperty Maximum) -4))"; Expression = "Name"}
            if ($Config.ShowPoolBalancesDetails) {
                $Columns += $BalancesData.Balances | ForEach-Object {$_.PSObject.Properties.Name} | Where-Object {$_ -like "Balance (*"} | Select-Object -Unique
            }
            else {
                $ColumnFormat += @{Name = "Balance$(' ' * (($BalancesData.Balances.Balance | Select-Object | ForEach-Object {$_.ToString()} | Measure-Object Length -Maximum | Select-Object -ExpandProperty Maximum) -7))"; Expression = {$_.Total}}
            }
            $Columns += $BalancesData.Balances | ForEach-Object {$_.PSObject.Properties.Name} | Where-Object {$_ -like "Value in *"} | Select-Object -Unique
            $ColumnFormat += $Columns | ForEach-Object {@{Name = "$_"; Expression = "$_"; Align = "right"}}
            if (($BalancesData.Balances | Select-Object -Last 1 | Select-Object -ExpandProperty Name) -eq "*Total*") {
                #Insert footer separator
                $BalancesData.Balances += ($BalancesData.Balances | Select-Object -Last 1).PsObject.Copy()
                $BalancesData.Balances += ($BalancesData.Balances | Select-Object -Last 1).PsObject.Copy()
                ($BalancesData.Balances | Select-Object -Last 1).PSObject.Properties.Name | ForEach-Object {
                    ($BalancesData.Balances | Select-Object -Last 1 -Skip 2) | Add-Member $_ "$('-' * ($BalancesData.Balances.$_ | Select-Object | ForEach-Object {$_.ToString()} | Measure-Object Length -Maximum | Select-Object -ExpandProperty Maximum))" -Force
                    ($BalancesData.Balances | Select-Object -Last 1 ) | Add-Member $_ "$('=' * ($BalancesData.Balances.$_ | Select-Object | ForEach-Object {$_.ToString()} | Measure-Object Length -Maximum | Select-Object -ExpandProperty Maximum))" -Force
                }
            }
            $BalancesData.Balances | Format-Table -Wrap -Property $ColumnFormat
        }
    }

    if ($NewRates) {
        #Display exchange rates, get decimal places from $NewRates
        if (($Config.ShowPoolBalances -or $Config.ShowPoolBalancesExcludedPools) -and $Config.ShowPoolBalancesDetails -and $BalancesData.Rates) {
            Write-Host "Exchange rates:"
            $BalancesData.Rates.PSObject.Properties.Name | ForEach-Object {
                $BalanceCurrency = $_
                Write-Host "1 $BalanceCurrency = $(($BalancesData.Rates.$_.PSObject.Properties.Name | Where-Object {$_ -ne $BalanceCurrency} | Sort-Object | ForEach-Object {
                    "$($_.ToUpper()) $(ConvertTo-LocalCurrency -Value $BalancesData.Rates.$BalanceCurrency.$_ -BTCRate $NewRates.BTC -Offset 2)"
                }) -join " = ")"
            }
        }
        else {
            if ($Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_}) {Write-Host "Exchange rates: 1 BTC = $(($Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_} | ForEach-Object {"$($_.ToUpper()) " + ("{0:N$(if($(($NewRates.$_).ToString().Split(".")[1]).length -gt 2) {2} else {$(($NewRates.$_).ToString().Split(".")[1]).length})}" -f [Float]$NewRates.$_)}) -join " = ")"}
        }
    }

    #Give API access to WatchdogTimers information
    $API.WatchdogTimers = $WatchdogTimers

    #Reduce Memory
    Get-Job | Where-Object {$_.Name -eq "Downloader" -and $_.State -eq "Completed"} | Remove-Job
    [GC]::Collect()

    if ($RunningMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null}) {
        #Ensure a minimal benchmarking interval if no stored hashrate
        if ($RunningMiners | Where-Object Speed -EQ $null) {
            #Ensure a full benchmarking interval if no reported hashrate
            $StatEnd = (Get-Date).ToUniversalTime().AddSeconds($Config.BenchmarkInterval)
        }
        elseif ((Get-Date).ToUniversalTime().AddSeconds($Config.BenchmarkInterval / 2) -lt $StatEnd) {
            #Ensure at least half a benchmarking interval if reported  hashrate
            $StatEnd = (Get-Date).ToUniversalTime().AddSeconds($Config.BenchmarkInterval / 2)
        }
    }
    elseif ((Get-Date).ToUniversalTime().AddSeconds($Config.Interval / 2) -lt $StatEnd) {
        # Ensure minimum half loop duration
        $StatEnd = (Get-Date).ToUniversalTime().AddSeconds($Config.Interval / 2)
    }
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    #Read hash rate info from miners as to not overload the APIs and display miner download status
    Write-Log "Start waiting before next run. "
    Do {
        $Timer = (Get-Date).ToUniversalTime()
        if ($Downloader) {$Downloader | Receive-Job}
        if ($API.Stop) {Exit}

        #Update monitoring service at start of each interval and then every 60 seconds
        if ($ActiveMiners -and $Config.MinerStatusURL -like "http*" -and $Config.MinerStatusKey -and ($StatStart -gt $LastReport -or $Timer -gt $LastReport.AddSeconds(60))) {
            $ReportStatusJob | Remove-Job -Force -ErrorAction SilentlyContinue
            $ReportStatusJob = Start-Job -Name "ReportStatus" -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList $Config, $ActiveMiners -FilePath .\ReportStatus.ps1
            $LastReport = (Get-Date).ToUniversalTime()
        }

        $ActiveMiners | Where-Object Best | Where-Object Status -EQ "Running" | ForEach-Object {
            $Miner = $_
            if ($Miner.GetStatus() -eq "Running") {
                $Miner_Data = $Miner.UpdateMinerData()
                if (@($Miner.Data | Where-Object {$_.Date -GE $StatStart}).count) {
                    $Sample = $Miner.Data | Select-Object -last 1
                    Write-Log -Level Verbose "$($Miner.Name) data sample retrieved: [$(($Sample.Hashrate.PSObject.Properties.Name | ForEach-Object {"$_ = $(($Sample.Hashrate.$_ | ConvertTo-Hash) -replace ' ')"}) -join '; ')] (total samples: $($Miner.Data.count) [$(($Miner.Data | Select-Object -First 1).Date.ToLongTimeString()) - $(($Miner.Data | Select-Object -Last 1).Date.ToLongTimeString())])"
                }
                if ($Miner.Speed -contains $null -and $Timer -ge $StatEnd) {
                    #Must have at least one sample from the current loop, otherwise we cannot detect broken miners
                    if (@($Miner.Data | Where-Object Date -GE $StatStart).count -lt $Config.MinHashRateSamples) {
                        #Extend loop time, enforce minimum hashrate samples when benchmarking
                        $StatEnd = (Get-Date).ToUniversalTime()
                        $StatSpan = New-TimeSpan $StatStart $StatEnd
                    }
                }
            }
            if ($Miner.GetStatus() -eq "Failed") {
                Write-Log -Level Error "Miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")}) has failed. "
                # Update API information
                $API.RunningMiners = $RunningMiners = @($RunningMiners | Where-Object {$_ -ne $Miner})
                $API.FailedMiners += $Miner
            }
        }

        if (-not $RunningMiners) {
            #No more running miners, start new loop immediately
            break
        }
        elseif ($ActiveMiners | Where-Object Best | Where-Object Speed -contains $null) {
            #We're benchmarking
            if (-not ($RunningMiners | Where-Object Speed -contains $null)) {
                #All benchmarking miners have failed, start new loop immediately
                $StatEnd = (Get-Date).ToUniversalTime()
                $StatSpan = New-TimeSpan $StatStart $StatEnd
                break
            }
            if ((($RunningMiners | Where-Object Speed -contains $null | ForEach-Object {$_.Data.Count}) | Measure-Object -Minimum).Minimum -ge $Config.MinHashRateSamples) {
                #All benchmarking miners have at least MinHashRateSamples hash rate samples, start new loop immediately
                $StatEnd = (Get-Date).ToUniversalTime()
                $StatSpan = New-TimeSpan $StatStart $StatEnd
                break
            }
        }

        #Kick watchdog
        $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
        $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

        #Pre-load pool information
        if ((Test-Path "Pools" -PathType Container) -and -not $GetPoolDataJobs.Count -and ($StatEnd - $Timer).TotalSeconds -lt $GetPoolDataJobsDuration) {
            Write-Log "Pre-loading pool information"
            Get-ChildItem "Pools" -File | Where-Object {$Config.Pools.$($_.BaseName) -and $Config.ExcludePoolName -inotcontains $_.BaseName} | Where-Object {$Config.PoolName.Count -eq 0 -or $Config.PoolName -contains $_.BaseName} | ForEach-Object {
                $Pool_Name = $_.BaseName
                $Pool_Parameters = @{StatSpan = $StatSpan}
                $Config.Pools.$Pool_Name | Get-Member -MemberType NoteProperty | ForEach-Object {$Pool_Parameters.($_.Name) = $Config.Pools.$Pool_Name.($_.Name)}
                $GetPoolDataJobs += Start-Job -Name "GetPoolData_$($Pool_Name)" -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList $Pool_Name, "Pools\$($_.Name)", $Pool_Parameters -FilePath .\Get-PoolData.ps1
            }
        }

        if ($Timer -le $StatEnd) {
            #Dynamically adjust waiting time
            $SleepTime = (0, (60 / $Config.HashRateSamplesPerMinute - ((Get-Date).ToUniversalTime() - $Timer).TotalSeconds) | Measure-Object -Maximum).Maximum
            if ($SleepTime) {Start-Sleep $SleepTime}
        }

    } While ($Timer -le $StatEnd)

    Write-Log "Finish waiting before next run. "

    #Save current hash rates
    Write-Log "Saving hash rates. "
    $RunningMiners | ForEach-Object {
        $Miner = $_
        $Miner.Speed_Live = [Double[]]@()

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_)_HashRate")})}

        if ($Miner.New) {$Miner.Benchmarked++}

        if ($Miner.GetStatus() -eq "Running" -or $Miner.New) {
            #Read miner speed from miner data
            $Miner.Algorithm | ForEach-Object {
                $Algorithm = $_ -replace "-NHMP"
                $Miner_Speed = [Double]($Miner.GetHashRate($Algorithm, ($Config.Interval * $Miner.BenchmarkIntervals), ($Miner.New -and $Miner.Benchmarked -lt $Miner.BenchmarkIntervals)))
                $Miner.Speed_Live += [Double]$Miner_Speed

                #Limit benchmarking loops
                if ((-not $Miner.New -and $Miner.Data.Count -gt $Config.MinHashRateSamples) -or ($Miner.New -and $Miner.Benchmarked -ge $Miner.BenchmarkIntervals) -or ($Miner.GetActivateCount() -ge $Strikes)) {
                    if ($Config.VerboseOutput) {Write-Log -Level Verbose "Saving hash rate ($($Miner.Name)_$($_)_HashRate: $(($Miner_Speed | ConvertTo-Hash) -replace ' '))"}
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Value $Miner_Speed -Duration $StatSpan -FaultDetection ($Miner.BenchmarkIntervals -le 1)
                    if (($Miner.GetActivateCount() -ge $Strikes) -and ($Miner.Benchmarked -ge $Miner.BenchmarkIntervals) -and -not $Miner_Speed) {Write-Log -Level Warn "Benchmarking: Miner ($Miner_Name {$(($Miner.Algorithm | ForEach-Object {"$($_ -replace '-NHMP' -replace 'NiceHash')@$($Pools.$_.Name)"}) -join "; ")}) did not report any valid hashrate and will be disabled. To re-enable remove the stats file. "}
                }

                #Update watchdog timer
                $Miner_Name = $Miner.Name
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                    $WatchdogTimer.Kicked = $Stat.Updated
                }
                #Always kick watchdog for new miners or running miners with at least one and less than MinHashRateSamples hash rate samples in current loop
                elseif ($WatchdogTimer -and ($Miner.New -and ($Miner.Data | Where-Object Date -GE $StatStart).Count -and $Miner.Data | Where-Object Date -GE $StatStart).Count -lt $Config.MinHashRateSamples) {
                    $WatchdogTimer.Kicked = (Get-Date).ToUniversalTime()
                }
            }
        }
    }
    Write-Log "Starting next run. "
}

#Stop the log
Stop-Transcript
