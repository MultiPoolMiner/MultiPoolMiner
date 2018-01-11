using module .\Include.psm1

$ProgressPreference = 'silentlyContinue' 
. .\MyInclude.ps1

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

# Make sure there is a log directory
if (-not (Test-Path "Logs")) {New-Item "Logs" -ItemType "directory" | Out-Null}
if (-not (Test-Path "Cache")) {New-Item "Cache" -ItemType "directory" | Out-Null}
if (-not (Test-Path "Data")) {New-Item "Data" -ItemType "directory" | Out-Null}

# Read configuration
Write-Log -Message "Applying configuration from Config.ps1..."
. .\Config.ps1
$ConfigTimeStamp = (Get-ChildItem "Config.ps1").LastWriteTime.ToUniversalTime()
#
#if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}
#if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
#    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
#}

if ($Proxy -eq "") {$PSDefaultParameterValues.Remove("*:Proxy")}
else {$PSDefaultParameterValues["*:Proxy"] = $Proxy}

$Algorithm = $Algorithm | ForEach-Object {Get-Algorithm $_}
$ExcludeAlgorithm = $ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_}
$Region = $Region | ForEach-Object {Get-Region $_}

$Strikes = 3

$Timer = (Get-Date).ToUniversalTime()

$StatEnd = $Timer

$DecayStart = $Timer
$DecayPeriod = 60 #seconds
$DecayBase = 1 - 0.1 #decimal percentage

$IntervalBackup = $Interval
$WatchdogInterval = $Interval * $Strikes
$WatchdogReset = $Interval * $Strikes * $Strikes * $Strikes

$WatchdogTimers = @()

$ActiveMiners = @()

$Rates = [PSCustomObject]@{BTC = [Double]1}

#Start the log
Start-Transcript ".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

##
##Check for software updates
#$Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList ("6.1", $PSVersionTable.PSVersion, "") -FilePath .\Updater.ps1

#Set donation parameters
if ($Donate -lt 10) {$Donate = 10}
$LastDonated = $Timer.AddDays(-1).AddHours(1)
$WalletDonate = @("1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb","3JQt8RezoGeEmA5ziAKNvxk34cM9JWsMCo")
$UserNameDonate = @("aaronsace","uselessguru")
$WorkerNameDonate = "mpm_uge"
$WalletBackup = $Wallet
$UserNameBackup = $UserName
$WorkerNameBackup = $WorkerName
$PayoutCurrencyBackup = $PayoutCurrency
$DonateDistribution = 0,0,0,0,0,0,0,0,1,1 #8:2

# UselessGuru: Support for power & profit calculation; read device information
$GPUs = (Get-GPUdevices $Type $DeviceSubTypes)

#UselessGuru: Debug stuff
if (Test-Path "DebugIn\GPUs.xml") {
    $GPUs = Import-CliXML -Path "DebugIn\GPUs.xml"
}
elseif (Test-Path "Debug") {
    [OpenCl.Platform]::GetPlatformIDs() | Out-File "Debug\OpenCL1.txt"
    [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)} | Out-File "Debug\OpenCL2.txt"
    $GPUs | Export-Clixml -Path "Debug\GPUs.xml"
}

# Read API definitions
Write-Log -Message "Loading miner APIs..."
Get-ChildItem "APIs" -Exclude "_*" | ForEach-Object {. $_.FullName}

while ($true) {
    if ((Get-ChildItem "Config.ps1").LastWriteTime.ToUniversalTime() -gt $ConfigTimeStamp) {
        # File has changed since last loop; re-read config -  this allows for dynamic configration changes
        Write-Log -Message "Configuration data has been modified - applying configuration from Config.ps1..."
        $BenchmarkInterval = $null
        . .\Config.ps1
        $ConfigTimeStamp = (Get-ChildItem "Config.ps1").LastWriteTime.ToUniversalTime() 
        
        if ($Proxy -eq "") {$PSDefaultParameterValues.Remove("*:Proxy")}
        else {$PSDefaultParameterValues["*:Proxy"] = $Proxy}

        $ExcludeAlgorithm = $ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_}
        $Region = $Region | ForEach-Object {Get-Region $_}
        $GPUs = (Get-GPUdevices $Type $DeviceSubTypes)
        $WalletBackup = $Wallet
        $UserNameBackup = $UserName
        $WorkerNameBackup = $WorkerName

        $IntervalBackup = $Interval

        Get-ChildItem "APIs" -Exclude "_*" | ForEach-Object {. $_.FullName}
    }
    $Timer = (Get-Date).ToUniversalTime()

    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)

    if ($BenchmarkInterval) {
        if ($BenchmarkMode) {$Interval = $BenchmarkInterval} else {$Interval = $IntervalBackup}
    }

    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

    #Activate or deactivate donation
    # Begin UselessGuru: Donation allocation
    if ($Timer.AddDays(-1).AddMinutes($Donate) -ge $LastDonated -and $Wallet -notcontains $WalletDonate -and $UserNameDonate -inotcontains $UserName) {
        if ($Wallet) {$Wallet = $WalletDonate[(Get-Random -InputObject $DonateDistribution)]}
        if ($UserName) {$UserName = $UserNameDonate[(Get-Random -InputObject $DonateDistribution)]}
        if ($WorkerName) {$WorkerName = $WorkerNameDonate}
        $PayoutCurrency = "BTC"
    }
    if ($Timer.AddDays(-1) -ge $LastDonated) {
        $Wallet = $WalletBackup
        $UserName = $UserNameBackup
        $WorkerName = $WorkerNameBackup
        $PayoutCurrency = $PayoutCurrencyBackup
        $LastDonated = $Timer
    }
    # End UselessGuru: Donation allocation

    #Update the exchange rates
    try {
        Write-Log -Message "Updating exchange rates from Coinbase..."
        $NewRates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
        $Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Rates | Add-Member $_ ([Double]$NewRates.$_) -Force}
    }
    catch {
        Write-Log -Level Warn -Message "Coinbase is down. "
    }

    #Load the stats
    Write-Log -Message "Loading saved statistics..."	
    $Stats = [PSCustomObject]@{}
    if (Test-Path "Stats") {Get-ChildItemContent "Stats" | ForEach-Object {$Stats | Add-Member $_.Name $_.Content}}

    if (Test-Path "DebugIn\Stats-*.xml") {$Stats = Import-Clixml -Path "DebugIn\Stats-*.xml"}
    elseif (Test-Path "Debug") {
        $Stats | Export-Clixml -Path "Debug\Stats-$((Get-Date).ticks).xml"
        Get-ChildItem "Stats" -Recurse | Out-File "Debug\Stats.lst"
    }

    #Load information about the pools
	Write-Log -Message "Loading pool information..."
    $NewPools = @()
    if (Test-Path "Pools") {
        $NewPools = Get-ChildItemContent "Pools" -Parameters @{Wallet = $Wallet; UserName = $UserName; Password = $Password; WorkerName = $WorkerName; StatSpan = $StatSpan; Algorithm = $Algorithm; PayoutCurrency = $PayoutCurrency; ProfitLessFee = $ProfitLessFee; MinPoolWorkers = $MinPoolWorkers; UseShortPoolNames = $UseShortPoolNames} | ForEach-Object {$_.Content | Add-Member Name $_.Name -Force -PassThru}
        <# $NewPools = Get-ChildItemContent "Pools" -Parameters @{Wallet = $Wallet; UserName = $UserName; WorkerName = $WorkerName; StatSpan = $StatSpan} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru} #>
    }
    # Debug stuff
    if (Test-Path "DebugIn\NewPools-*.xml") {$NewPools = Import-Clixml -Path "DebugIn\NewPools-*.xml"}
    elseif (Test-Path "Debug") {$NewPools | Export-Clixml -Path "Debug\NewPools-$((Get-Date).ticks).xml"}
    
    # This finds any pools that were already in $AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    # since mining is probably still working. Then it filters out any algorithms that aren't being used.
	$AllPools = @($NewPools) + @(Compare-Object @($NewPools | Select-Object -ExpandProperty Name -Unique) @($AllPools | Select-Object -ExpandProperty Name -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$AllPools | Where-Object Name -EQ $_}) | 
        Where-Object {$Algorithm.Count -eq 0 -or (Compare-Object $Algorithm $_.Algorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$ExcludeAlgorithm.Count -eq 0 -or (Compare-Object $ExcludeAlgorithm $_.Algorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}

    if (Test-Path "DebugIn\AllPools-*.xml") {$AllPools = Import-Clixml -Path "DebugIn\AllPools-*.xml"}
    elseif (Test-Path "Debug") {
        $AllPools | Export-Clixml -Path "Debug\AllPools-$((Get-Date).ticks).xml"
        Get-ChildItem "Pools" -Recurse | Out-File "Debug\Pools.lst"
    }

    #Remove non-present pools
    if (-not (Test-Path "DebugIn")) {$AllPools = $AllPools | Where-Object {Test-Path "Pools\$($_.Name).ps1"}}

    #Apply watchdog to pools
    $AllPools = $AllPools | Where-Object {
        $Pool = $_
        $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
    }

    #Update the active pools
    if ($AllPools.Count -eq 0) {
            Write-Log -Level Warn -Message "No pools available. "
        if ($Downloader) {$Downloader | Receive-Job}
        if (-not $Benchmarkmode) { 
            Start-Sleep $Interval
            continue
        }
    }
    $Pools = [PSCustomObject]@{}
    Write-Log -Message "Selecting best pool for each algorithm..."
    $AllPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($AllPools | Sort-Object -Descending {$PoolName.Count -eq 0 -or (Compare-Object $PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}, {$ExcludePoolName.Count -eq 0 -or (Compare-Object $ExcludePoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}, {$_.StablePrice * (1 - $_.MarginOfError)}, {$_.Region -EQ $Region}, {$_.SSL -EQ $SSL} | Where-Object Algorithm -EQ $_ | Select-Object -First 1)}
    if (($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_} | Measure-Object Updated -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalSeconds) -gt $Interval * $Strikes) {
            Write-Log -Level Warn -Message "Pool prices are out of sync. "
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Bias ($Pools.$_.StablePrice * (1 - ($Pools.$_.MarginOfError * $SwitchingPrevention * [Math]::Pow($DecayBase, $DecayExponent)))) -Force}
    }
    else {
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Bias ($Pools.$_.Price * (1 - ($Pools.$_.MarginOfError * $SwitchingPrevention * [Math]::Pow($DecayBase, $DecayExponent)))) -Force}
    }
    # Debug stuff
    if (Test-Path "DebugIn\Pools-*.xml") {$Pools = Import-Clixml -Path "DebugIn\Pools-*.xml"}
    elseif (Test-Path "Debug") {$Pools | Export-Clixml -Path "Debug\Pools-$((Get-Date).ticks).xml"}

    #Load information about the miners
    #Messy...?
    Write-Log -Message "Getting miner information..."
    # Get all the miners, get just the .Content property and add the name, select only the ones that match our $Type (CPU, AMD, NVIDIA) or all of them if type is unset,
    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $MinerName, if specified, and don't match $ExcludeMinerName
    if (Test-Path "Debug") {
        Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; StatSpan = $StatSpan; GPUs = $GPUs} | ForEach-Object {$_.Content | Add-Member Name $_.Name -Force -PassThru} | Export-Clixml -Path "Debug\Miners1-$((Get-Date).ticks).xml"
        Get-ChildItem "Miners" -Recurse | Out-File "Debug\Miners.lst"
    }
    $AllMiners = if (Test-Path "Miners") {
        Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; StatSpan = $StatSpan; GPUs = $GPUs} | ForEach-Object {$_.Content | Add-Member Name $_.Name -Force -PassThru} | <# UselessGuru#>
        <# Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats} | ForEach-Object {$_.Content | Add-Member Name $_.Name -PassThru} | #>
            Where-Object {$Type.Count -eq 0 -or (Compare-Object $Type $_.Type -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
            Where-Object {($Algorithm.Count -eq 0 -or (Compare-Object $Algorithm $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0) -and ((Compare-Object $Pools.PSObject.Properties.Name $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0)} | 
            Where-Object {$ExcludeAlgorithm.Count -eq 0 -or (Compare-Object $ExcludeAlgorithm $_.HashRates.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
            Where-Object {$MinerName.Count -eq 0 -or (Compare-Object $MinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
            Where-Object {$ExcludeMinerName.Count -eq 0 -or (Compare-Object $ExcludeMinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}
    }
    if (Test-Path "DebugIn\AllMiners-*.xml") {$AllMiners = Import-Clixml -Path "DebugIn\AllMiners-*.xml"}
    elseif (Test-Path "Debug") {$AllMiners | Export-Clixml -Path "Debug\AllMiners-$((Get-Date).ticks).xml"}
    
    # UselessGuru: By default mining is NOT profitable
    $MiningIsProfitable = $false
    # UselessGuru: By default no benchmark mode
    $BenchmarkMode = $false
    
    Write-Log -Message "Calculating profit for each miner..."
    $AllMiners | ForEach-Object {
        $Miner = $_

        # UselessGuru: Support for power & profit calculation
	    # Default ComputeUsage (in %, 100 = max))
        if ($Miner.ComputeUsage -eq $null -or $Miner.ComputeUsage -eq "") {
            $Miner | Add-Member ComputeUsage 100 -Force
        }
        $Miner.ComputeUsage = [Double]$Miner.ComputeUsage
        
        # Begin UselessGuru: Support for power & profit calculation
        # Default power consumption 
        $Miner.PowerDraw = [Double]$Miner.PowerDraw

        # Convert power cost back to BTC, all profit calculations are done in BTC
        Try {
            $Miner_PowerCost = [Double](([Double]$Miner.PowerDraw + [Double]($Computer_PowerDraw / $GPUs.Device.Count)) / 1000 * 24 * [Double]$PowerPricePerKW / $Rates.$($Currency[0]))
        }
        Catch {
            $Miner_PowerCost = 0
        }
        if ($PowerPricePerKW -eq 0) {$Miner_PowerCost = 0}
        
        $Miner | Add-Member PowerCost $Miner_PowerCost -Force
        # End UselessGuru: Support for power & profit calculation


        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Earnings = [PSCustomObject]@{} <# UselessGuru #>
        $Miner_Earnings_Comparison = [PSCustomObject]@{} <# UselessGuru #>
        $Miner_Profits = [PSCustomObject]@{}
        $Miner_Profits_Comparison = [PSCustomObject]@{}
        $Miner_Profits_MarginOfError = [PSCustomObject]@{}
        $Miner_Profits_Bias = [PSCustomObject]@{}

        $Miner_Types = $Miner.Type | Select-Object -Unique
        $Miner_Indexes = $Miner.Index | Select-Object -Unique
        $Miner_Devices = $Miner.Device | Select-Object -Unique
		
		
		$Miner.HashRates.PSObject.Properties.Name | ForEach-Object { #temp fix, must use 'PSObject.Properties' to preserve order
            $Miner_HashRates | Add-Member $_ ([Double]$Miner.HashRates.$_)
            $Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Pools_Comparison | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Earnings | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price) <# UselessGuru, added powercosts #>
            $Miner_Earnings_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice) <# UselessGuru, added powercosts #>
            $Miner_Profits_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Bias)
        }

        # UselessGuru: Power & profit calculation
        $Miner_Earning = [Double]($Miner_Earnings.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Earning_Comparison = [Double](($Miner_Earnings_Comparison.PSObject.Properties.Value | Measure-Object -Sum).Sum) <# UselessGuru #>
        $Miner_Profit_Bias = [Double]($Miner_Profits_Bias.PSObject.Properties.Value | Measure-Object -Sum).Sum

        $Miner_Profit = [Double]($Miner_Earning - $Miner_PowerCost) <# UselessGuru #>
		$Miner_Profit_Comparison = [Double]($Miner_Earning_Comparison - $Miner_PowerCost) <# UselessGuru #>
		
		$Miner.HashRates.PSObject.Properties.Name | ForEach-Object {
			$Miner_Profits | Add-Member $_ ([Double]($Miner.HashRates.$_ * $Pools.$_.Price) - ($Miner_PowerCost * ($Miner_Earning / ($Miner.HashRates.$_ * $Pools.$_.Price))))
			$Miner_Profits_Comparison | Add-Member $_ ([Double]($Miner.HashRates.$_ * $Pools.$_.Price) - ($Miner_PowerCost * ($Miner_Earning_Comparison / ($Miner.HashRates.$_ * $Pools.$_.Price))))
		}
		
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
                $Miner_Profit = $null
                $Miner_Profit_Comparison = $null
                $Miner_Profits_MarginOfError = $null
                $Miner_Profit_Bias = $null
                $Miner_Earning = $null <# UselessGuru: Power & profit calculation #>
                $BenchmarkMode = $true  <# UselessGuru: Enable benchmark mode on empty has rates #>
            }
        }

         # No power data, Will force benchmarking
        if ($ForceBenchmarkOnMissingPowerData -and  $PowerPricePerKW -gt 0 -and $Miner.PowerDraw -le 0) {
            $Miner_Profit = $null
            $Miner_Profit_Comparison = $null
            $BenchmarkMode = $true
        }

        if ($Miner_Types -eq $null) {$Miner_Types = $AllMiners.Type | Select-Object -Unique}
        if ($Miner_Indexes -eq $null) {$Miner_Indexes = $AllMiners.Index | Select-Object -Unique}

        if ($Miner_Types -eq $null) {$Miner_Types = ""}
        if ($Miner_Indexes -eq $null) {$Miner_Indexes = "All"}

        # UselessGuru: Show device IDs in mining overview
        if ($Miner_Type -ne "CPU") {
            if ($Miner.Index -like "*,*") {
                $Miner_Devices = "$($Miner_Devices) [GPU Device ID: $($Miner.Index)]"
            }
            elseif ($Miner.Index -like "") {
                $Miner_Devices = "$($Miner_Devices) [GPU Device ID: $(($GPUs.Device | Where-Object {$_.Type -eq $Miner_Types}).Devices -join ",")]"
            }
            else {
                $Miner_Devices = "$($Miner_Devices) [GPU Device ID: $($Miner.Index)]"
            }
        }
        # End UselessGuru: Show device IDs in mining overview

        $Miner.HashRates = $Miner_HashRates

        $Miner | Add-Member Pools $Miner_Pools
        $Miner | Add-Member Profits $Miner_Profits
        $Miner | Add-Member Profits_Comparison $Miner_Profits_Comparison
        $Miner | Add-Member Profits_Bias $Miner_Profits_Bias
        $Miner | Add-Member Profit $Miner_Profit
        $Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
        $Miner | Add-Member Profit_MarginOfError $Miner_Profit_MarginOfError
        $Miner | Add-Member Profit_Bias $Miner_Profit_Bias

        $Miner | Add-Member Earnings $Miner_Earnings <# UselessGuru: Power & profit calculation #>
        $Miner | Add-Member Earning $Miner_Earning <# UselessGuru: Power & profit calculation #>

        $Miner | Add-Member Type ($Miner_Types | Sort-Object) -Force
        $Miner | Add-Member Index ($Miner_Indexes | Sort-Object) -Force

        $Miner | Add-Member Device ($Miner_Devices | Sort-Object) -Force
        $Miner | Add-Member Device_Auto (($Miner_Devices -eq $null) | Sort-Object) -Force

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if (-not $Miner.API) {$Miner | Add-Member API "Miner" -Force}
    }

    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath))}
    if ($Downloader.State -ne "Running") {
        $Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList (@($AllMiners | Where-Object {$_.PrerequisitePath} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}) + @($AllMiners | Select-Object URI, Path, @{name = "Searchable"; expression = {$Miner = $_; ($AllMiners | Where-Object {(Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI}).Count -eq 0}}) | Select-Object * -Unique) -FilePath .\Downloader.ps1
    }
    #Debug stuff
    if (Test-Path "DebugIn\Miners-*.xml") {$Miners = Import-Clixml -Path "DebugIn\Miners-*.xml"}
    elseif (Test-Path "Debug") {$Miners | Export-Clixml -Path "Debug\Miners-$((Get-Date).ticks).xml"}

    # Open firewall ports for all miners
    if (Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) {
        if ((Get-Command "Get-MpComputerStatus" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
            if (Get-Command "Get-NetFirewallRule" -ErrorAction SilentlyContinue) {
                if ($MinerFirewalls -eq $null) {$MinerFirewalls = Get-NetFirewallApplicationFilter | Select-Object -ExpandProperty Program}
                if (@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ "=>") {
                    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'; ('$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Compress)' | ConvertFrom-Json) | ForEach {New-NetFirewallRule -DisplayName 'MultiPoolMiner' -Program `$_}" -replace '"', '\"') -Verb runAs
                    $MinerFirewalls = $null
                }
            }
        }
    }

    #Apply watchdog to miners
    $Miners = $Miners | Where-Object {
        $Miner = $_
        $Miner_WatchdogTimers = $WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
        ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
    }

    #Update the active miners
    if ($Miners.Count -eq 0) {
        if ($AllMiners.Count -gt 0 -and (Get-ChildItem "Bin" -ErrorAction SilentlyContinue).count -eq 0) {
            Write-Log -Level Info -Message "No miners binary available. They will be downloaded automatically, please wait... "
        }
        else {
            Write-Log -Level Warn -Message "No miners available. "
        }
        if ($Downloader) {$Downloader | Receive-Job}
        if ($DisplayProfitOnly) {Start-Sleep ($Interval / 10)} else {Start-Sleep $Interval} <# UselessGuru #>
        <# Start-Sleep $Interval #>
        continue
    }
    $ActiveMiners | ForEach-Object {
        $_.Earning = 0 <# UselessGuru #>
        $_.Profit = 0
        $_.Profit_Comparison = 0
        $_.Profit_MarginOfError = 0
        $_.Profit_Bias = 0
        $_.Best = $false
        $_.Best_Comparison = $false
    }
    $Miners | Sort-Object { $_.HashRates.PSObject.Properties.Name } | ForEach-Object {
        $Miner = $_
        # Begin UselessGuru: Avoid swiching on different ports
        $ActiveMiner = $ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and 
            $_.Path -eq $Miner.Path -and
            $_.API -eq $Miner.API -and 
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }
        # End UselessGuru: Avoid swiching on different ports
        if ($ActiveMiner) {
            $ActiveMiner.Type = $Miner.Type
            $ActiveMiner.Index = $Miner.Index
            $ActiveMiner.Device = $Miner.Device
            $ActiveMiner.Device_Auto = $Miner.Device_Auto
            $ActiveMiner.Profit = $Miner.Profit
            $ActiveMiner.Profit_Comparison = $Miner.Profit_Comparison
            $ActiveMiner.Profit_MarginOfError = $Miner.Profit_MarginOfError
            $ActiveMiner.Profit_Bias = $Miner.Profit_Bias
            $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order

            # Begin UselessGuru: Support for power & profit calculation
            $ActiveMiner.Earning = $Miner.Earning
            $ActiveMiner.PowerDraw = [Double]$Miner.PowerDraw
            $ActiveMiner.ComputeUsage = [Double]$Miner.ComputeUsage
            $ActiveMiner.Pool = $Miner.Pool
            # End UselessGuru: Support for power & profit calculation
        }
        else {
            $ActiveMiners += New-Object $Miner.API -Property @{
                Name                 = $Miner.Name
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                Wrap                 = $Miner.Wrap
                API                  = $Miner.API
                Port                 = $Miner.Port
                Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
                Type                 = $Miner.Type
                Index                = $Miner.Index
                Device               = $Miner.Device
                Device_Auto          = $Miner.Device_Auto
                Profit               = $Miner.Profit
                Profit_Comparison    = $Miner.Profit_Comparison
                Profit_MarginOfError = $Miner.Profit_MarginOfError
                Profit_Bias          = $Miner.Profit_Bias
                Speed                = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
                Speed_Live           = 0
                Best                 = $false
                Best_Comparison      = $false
                Process              = $null
                New                  = $false
                Active               = [TimeSpan]0
                Activated            = 0
                Status               = ""
                Benchmarked          = 0
                # Begin UselessGuru: Support for power & profit calculation
                Earning              = $Miner.Earning
                PowerDraw            = $Miner.PowerDraw
                PowerCost            = $Miner.PowerCost
                ComputeUsage         = $Miner.ComputeUsage
                Pool                 = $Miner.Pool
                # End UselessGuru: Support for power & profit calculation
            }
        }
    }

    # Debug Stuff
    if (Test-Path "DebugIn\ActiveMiners-*.xml") {$ActiveMiners = Import-Clixml -Path "DebugIn\ActiveMiners-*.xml"}
    elseif (Test-Path "Debug") {$ActiveMiners | Export-Clixml -Path "Debug\ActiveMiners-$((Get-Date).ticks).xml"}
    
    $ActiveMiners | Where-Object Device_Auto | ForEach-Object {
        $Miner = $_
        $Miner.Device = ($Miners | Where-Object {(Compare-Object $Miner.Type $_.Type -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}).Device | Select-Object -Unique | Sort-Object
        if ($Miner.Device -eq $null) {$Miner.Device = ($Miners | Where-Object {(Compare-Object $Miner.Type $_.Type -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}).Type | Select-Object -Unique | Sort-Object}
    }

    #Don't penalize active miners
    $ActiveMiners | Where-Object Status -EQ "Running" | ForEach-Object {$_.Profit_Bias = $_.Profit}

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $ActiveMiners | Select-Object Type, Index -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Type $_.Type | Measure-Object).Count -eq 0 -and (Compare-Object $Miner_GPU.Index $_.Index | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Algorithm}, {$_.Name} | Select-Object -First 1)}
    $BestDeviceMiners = $ActiveMiners | Select-Object Device -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Device $_.Device | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Algorithm} | Select-Object -First 1)}
    if ($DisplayComparison) { # UselessGuru: Support for $DisplayComparison
        $BestMiners_Comparison = $ActiveMiners | Select-Object Type, Index -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Type $_.Type | Measure-Object).Count -eq 0 -and (Compare-Object $Miner_GPU.Index $_.Index | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Algorithm}, {$_.Name} | Select-Object -First 1)}
        $BestDeviceMiners_Comparison = $ActiveMiners | Select-Object Device -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Device $_.Device | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Algorithm} | Select-Object -First 1)}
    }

    $Miners_Type_Combos = @([PSCustomObject]@{Combination = @()}) + (Get-Combination ($ActiveMiners | Select-Object Type -Unique) | Where-Object {(Compare-Object ($_.Combination | Select-Object -ExpandProperty Type -Unique) ($_.Combination | Select-Object -ExpandProperty Type) | Measure-Object).Count -eq 0})
    $Miners_Index_Combos = @([PSCustomObject]@{Combination = @()}) + (Get-Combination ($ActiveMiners | Select-Object Index -Unique) | Where-Object {(Compare-Object ($_.Combination | Select-Object -ExpandProperty Index -Unique) ($_.Combination | Select-Object -ExpandProperty Index) | Measure-Object).Count -eq 0})
    $Miners_Device_Combos = (Get-Combination ($ActiveMiners | Select-Object Device -Unique) | Where-Object {(Compare-Object ($_.Combination | Select-Object -ExpandProperty Device -Unique) ($_.Combination | Select-Object -ExpandProperty Device) | Measure-Object).Count -eq 0})
    $BestMiners_Combos = $Miners_Type_Combos | ForEach-Object {
        $Miner_Type_Combo = $_.Combination
        $Miners_Index_Combos | ForEach-Object {
            $Miner_Index_Combo = $_.Combination
            [PSCustomObject]@{
                Combination = $Miner_Type_Combo | ForEach-Object {
                    $Miner_Type_Count = $_.Type.Count
                    [Regex]$Miner_Type_Regex = "^(" + (($_.Type | ForEach-Object {[Regex]::Escape($_)}) -join "|") + ")$"
                    $Miner_Index_Combo | ForEach-Object {
                        $Miner_Index_Count = $_.Index.Count
                        [Regex]$Miner_Index_Regex = "^(" + (($_.Index | ForEach-Object {[Regex]::Escape($_)}) -join "|") + ")$"
                        $BestMiners | Where-Object {([Array]$_.Type -notmatch $Miner_Type_Regex).Count -eq 0 -and ([Array]$_.Index -notmatch $Miner_Index_Regex).Count -eq 0 -and ([Array]$_.Type -match $Miner_Type_Regex).Count -eq $Miner_Type_Count -and ([Array]$_.Index -match $Miner_Index_Regex).Count -eq $Miner_Index_Count}
                    }
                }
            }
        }
    }
    $BestMiners_Combos += $Miners_Device_Combos | ForEach-Object {
        $Miner_Device_Combo = $_.Combination
        [PSCustomObject]@{
            Combination = $Miner_Device_Combo | ForEach-Object {
                $Miner_Device_Count = $_.Device.Count
                [Regex]$Miner_Device_Regex = "^(" + (($_.Device | ForEach-Object {[Regex]::Escape($_)}) -join "|") + ")$"
                $BestDeviceMiners | Where-Object {([Array]$_.Device -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.Device -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
            }
        }
    }
    if ($DisplayComparison) { <# UselessGuru: Support for $DisplayComparison #>
        $BestMiners_Combos_Comparison = $Miners_Type_Combos | ForEach-Object {
            $Miner_Type_Combo = $_.Combination
            $Miners_Index_Combos | ForEach-Object {
                $Miner_Index_Combo = $_.Combination
                [PSCustomObject]@{
                    Combination = $Miner_Type_Combo | ForEach-Object {
                        $Miner_Type_Count = $_.Type.Count
                        [Regex]$Miner_Type_Regex = "^(" + (($_.Type | ForEach-Object {[Regex]::Escape($_)}) -join "|") + ")$"
                        $Miner_Index_Combo | ForEach-Object {
                            $Miner_Index_Count = $_.Index.Count
                            [Regex]$Miner_Index_Regex = "^(" + (($_.Index | ForEach-Object {[Regex]::Escape($_)}) -join "|") + ")$"
                            $BestMiners_Comparison | Where-Object {([Array]$_.Type -notmatch $Miner_Type_Regex).Count -eq 0 -and ([Array]$_.Index -notmatch $Miner_Index_Regex).Count -eq 0 -and ([Array]$_.Type -match $Miner_Type_Regex).Count -eq $Miner_Type_Count -and ([Array]$_.Index -match $Miner_Index_Regex).Count -eq $Miner_Index_Count}
                        }
                    }
                }
            }
        }
        $BestMiners_Combos_Comparison += $Miners_Device_Combos | ForEach-Object {
            $Miner_Device_Combo = $_.Combination
            [PSCustomObject]@{
                Combination = $Miner_Device_Combo | ForEach-Object {
                    $Miner_Device_Count = $_.Device.Count
                    [Regex]$Miner_Device_Regex = "^(" + (($_.Device | ForEach-Object {[Regex]::Escape($_)}) -join "|") + ")$"
                    $BestDeviceMiners_Comparison | Where-Object {([Array]$_.Device -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.Device -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
                }
            }
        }
    } <# UselessGuru: Support for $DisplayComparison #>
    
    $BestMiners_Combo = $BestMiners_Combos | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Bias -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count}, Algorithm | Select-Object -First 1 | Select-Object -ExpandProperty Combination
    $BestMiners_Combo | ForEach-Object {$_.Best = $true}
    if ($DisplayComparison) {$BestMiners_Combo_Comparison = $BestMiners_Combos_Comparison | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Comparison -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count}, Algorithm | Select-Object -First 1 | Select-Object -ExpandProperty Combination} <# UselessGuru : Support for $DisplayComparison #>
    if ($DisplayComparison) {$BestMiners_Combo_Comparison | ForEach-Object {$_.Best_Comparison = $true}} <# UselessGuru : Support for $DisplayComparison #>

    # Begin UselessGuru: Support for power & profit calculation, accumulate power & profit
    $Earnings= 0
    $Profits = 0
    $PowerCosts = 0
    $ActiveMiners | Select-Object Device -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Device $_.Device | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)} | ForEach-Object {
        $Earnings += $_.Earning
        $Profits += $_.Profit
        $PowerCosts += $_.PowerCost
    }
    # End UselessGuru: Support for power & profit calculation, accumulate power & profit
    
    $MiningIsProfitable = ($Profits * $Rates.$($Currency[0])) -ge $MinProfit <# UselessGuru: Determine mining profitability #>
    
    #Stop or start miners in the active list depending on if they are the most profitable
    $ActiveMiners | Where-Object Activated -GT 0 | Where-Object {$_.Best -EQ $false -or -not $MiningIsProfitable}  | Sort-Object -Descending {$_.Device} | ForEach-Object {
        $Miner = $_

        if ($Miner.Process -eq $null -or $Miner.Process.HasExited) {
            if ($Miner.Status -eq "Running") {$Miner.Status = "Failed"}
        }
        else {
            $Miner.Process.CloseMainWindow() | Out-Null
            $Miner.Status = "Idle"

            #Remove watchdog timer
            $Miner_Name = $Miner.Name
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($WatchdogTimer) {
                    if ($WatchdogTimer.Kicked -lt $Timer.AddSeconds( - $WatchdogInterval)) {
                        $Miner.Status = "Failed"
                        # Begin UselessGuru
                        if($Miner.Process -eq $null) {
                            Write-Log -Level Warn -Message "$($Miner.Type) miner '$($Miner.Name)' ($($Miner.Algorithm -join '|')) [GPU Devices: $($Miner.Index)] failed - process handle is missing"
                        }
                        if($Miner.Process.HasExited) {
                            Write-Log -Level Warn -Message "$($Miner.Type) miner '$($Miner.Name)' ($($Miner.Algorithm -join '|')) [GPU Devices: $($Miner.Index)] failed - process exited on it's own"
                        }
                        # End UselessGuru 
                   }
                    else {
                        $WatchdogTimers = $WatchdogTimers -notmatch $WatchdogTimer
                    }
                }
            }
        }
    }
    if ($Downloader) {$Downloader | Receive-Job}
    Start-Sleep $Delay #Wait to prevent BSOD

    if ($MiningIsProfitable -or $BenchmarkMode) { <# UselessGuru: Support $MiningIsProfitable switch #>
        $ActiveMiners | Where-Object Best -EQ $true | Sort-Object -Descending {$_.Device} | ForEach-Object {
            if ($_.Process -eq $null -or $_.Process.HasExited -ne $false) {
                "$(Split-Path $_.Path -leaf) $($_.Arguments)" | Out-File "$(Split-Path $_.Path)\$($_.Name)_$($_.Algorithm -join "-").cmd" -Encoding default <# UselessGuru: Write cmd file for each run miner #>
                
                $MinerInfo = "$($_.Type) miner '$($_.Name)' ($($_.Algorithm -join '|')) [GPU Devices: $($_.Index)]" <# UselessGuru #>
                if ($DisplayProfitOnly) {
                    Write-Log -Message "DisplayProfitOnly: Would be starting $($MinerInfo): '$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)'" <# UselessGuru #>
                }
                else {
                    Write-Log -Message "Starting $($MinerInfo): '$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)'" <# UselessGuru #>
                    $DecayStart = $Timer
                    # Set miner window style
                    $_.MinerWindowStyle = $MinerWindowStyle
                    $_.UseAlternateMinerLauncher = $UseAlternateMinerLauncher

                    #Launch the miner
                    $_.StartMining()
                    
                    if ($_.Process.Id) {
                        Write-Log -Message "Started $($MinerInfo) [PID $($_.Process.Id)]"
                    }
                    else {
                        Write-Log -Level Warn "$($MinerInfo) failed - process handle is missing"
                    }
                    #Add watchdog timer
                    if ($Watchdog -and $_.Profit -ne $null) {
                        $Miner_Name = $_.Name
                        $_.Algorithm | ForEach-Object {
                            $Miner_Algorithm = $_
                            $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                            if (-not $WatchdogTimer) {
                                $WatchdogTimers += [PSCustomObject]@{
                                    MinerName = $Miner_Name
                                    PoolName  = $Pools.$Miner_Algorithm.Name
                                    Algorithm = $Miner_Algorithm
                                    Kicked    = $Timer
                                    Command   = $Miner_Command <# UselessGuru: Display executed command in watchdog overview #>
                                }
                            }
                            elseif (-not ($WatchdogTimer.Kicked -GT $Timer.AddSeconds( - $WatchdogReset))) {
                                $WatchdogTimer.Kicked = $Timer
                            }
                        }
                    }
                }
            }
        }
    }  <# End UselessGuru: Support $MiningIsProfitable switch #>

    if ($MinerStatusURL) {& .\ReportStatus.ps1 -Address $WalletBackup -WorkerName $WorkerNameBackup -ActiveMiners $ActiveMiners -Miners $Miners -MinerStatusURL $MinerStatusURL}

    # Export variables for GUI and debugging purposes
    $ActiveMiners | Export-Clixml -Path 'Data\ActiveMiners.xml'
    $Miners | Export-Clixml -Path 'Data\Miners.xml'
    $Pools | Export-Clixml -Path 'Data\Pools.xml'
    $AllPools | Export-Clixml -Path 'Data\AllPools.xml'

#    if ($PowerPricePerKW -gt 0) { 
#        $PowerCostSummary = ScriptBlock {
#        @{Label = "Power Cost`n$($Currency[0])/Day"; Expression = {if ($PowerPricePerKW -eq 0) {"N/A"} else {if ($_.PowerDraw) {"-$(ConvertTo-LocalCurrency -Number $($_.PowerCost) -BTCRate $($Rates.$($Currency[0])))"} else {if ($_.Running) {"Measuring"} else {"Unknown"}}}}; Align = "right"},
#        @{Label = "Power Total`nWatt";		         Expression = {if ($PowerPricePerKW -eq 0) {"N/A"} else {if ($_.PowerDraw) {"$(($_.PowerDraw + ($Computer_PowerDraw / $GPUs.Device.count)).ToString("N2"))"} else {if ($_.Running) {"Measuring"} else {"Unknown"}}}}; Align ="right"},
#        @{Label = "Power GPU [+Base]`nWatt";         Expression = {if ($PowerPricePerKW -eq 0) {"N/A"} else {if ($_.PowerDraw) {"$($_.PowerDraw.ToString("N2")) [$($($Computer_PowerDraw / $GPUs.Device.count).ToString("N2"))]"} else {if ($_.Running) {"Measuring [$($($Computer_PowerDraw / $GPUs.Device.count).ToString("N2"))]"} else {"Unmeasured [$($($Computer_PowerDraw / $GPUs.Device.count).ToString("N2"))]"}}}}; Align = "right"}
#        }
#    }

    #Display mining information   
    if ($Poolname) {Write-Log -Message "Selected pool: $($Poolname)"}
    if ($Algorithm) {Write-Log -Message "Selected algorithms: $($Algorithm)"}
    $Miners | Where-Object {$BenchmarkMode -or $DisplayProfitOnly -or ($_.Earning -gt 0) -or ($_.Profit -eq $null)} | Sort-Object -Descending {$_.Device}, {$_.Profit_Bias}, {$_.Profit}, {$_.HashRates.PSObject.Properties.Name} | Format-Table -GroupBy Device (
        @{Label = "Miner";                           Expression = {$_.Name -replace "_$((Get-Culture).TextInfo.ToTitleCase(($_.Device -replace "-", " " -replace "_", " ")) -replace " ")",""}}, 
        @{Label = "Algorithm(s)";                    Expression = {($_.HashRates.PSObject.Properties.Name) -join " & "}},
        @{Label = "Profit`n$($Currency[0])/Day";     Expression = {if ($_.Profit) {ConvertTo-LocalCurrency -Number $($_.Profit) -BTCRate $($Rates.$($Currency[0]))} else {if ($_.Running) {"Measuring"} else {"Pending"}}}; Align = "right"},
#        if ($PowerPricePerKW -gt 0) { $PowerCostSummary,}
        @{Label = "Power Cost`n$($Currency[0])/Day"; Expression = {if ($PowerPricePerKW -eq 0) {"N/A"} else {if ($_.PowerDraw) {"-$(ConvertTo-LocalCurrency -Number $($_.PowerCost) -BTCRate $($Rates.$($Currency[0])))"} else {if ($_.Running) {"Measuring"} else {"Unknown"}}}}; Align = "right"},
        @{Label = "Power Total`nWatt";		         Expression = {if ($PowerPricePerKW -eq 0) {"N/A"} else {if ($_.PowerDraw) {"$(($_.PowerDraw + ($Computer_PowerDraw / $GPUs.Device.count)).ToString("N2"))"} else {if ($_.Running) {"Measuring"} else {"Unknown"}}}}; Align ="right"},
        @{Label = "Power GPU [+Base]`nWatt";         Expression = {if ($PowerPricePerKW -eq 0) {"N/A"} else {if ($_.PowerDraw) {"$($_.PowerDraw.ToString("N2")) [$($($Computer_PowerDraw / $GPUs.Device.count).ToString("N2"))]"} else {if ($_.Running) {"Measuring [$($($Computer_PowerDraw / $GPUs.Device.count).ToString("N2"))]"} else {"Unmeasured [$($($Computer_PowerDraw / $GPUs.Device.count).ToString("N2"))]"}}}}; Align = "right"},
        @{Label = "Earning`n$($Currency[0])/Day";    Expression = {if ($_.Earning) {ConvertTo-LocalCurrency -Number $($_.Earning) -BTCRate ($Rates.$($Currency[0]))} else {"Unknown"}}; Align = "right"},
        @{Label = "Accuracy";                        Expression = {($_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}) -join "|"}; Align = "right"}, 
        @{Label = "Speed(s)";                        Expression = {($_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"} else {if ($_.Running) {Benchmarking} else {"Benchmarking"}}}) -join "|"}; Align = "right"}, 
        @{Label = "GH/Day`n$($Currency[0])";         Expression = {($_.Pools.PSObject.Properties.Value.Price | ForEach-Object {ConvertTo-LocalCurrency -Number $($_ * 1000000000) -BTCRate $($Rates.$($Currency[0]))}) -join "+"}; Align = "right"}, 
        @{Label = "GH/Day`nBTC";                     Expression = {($_.Pools.PSObject.Properties.Value.Price | ForEach-Object {($_ * 1000000000)}) -join "+"}; Align = "right"}, 
        @{Label = "GPU Usage";                       Expression = {if ($_.Profit) {"$($_.ComputeUsage.ToString("N2"))%"} else {if ($_.Running) {"Measuring"} else {"Unmeasured"}}}; Align = "right"},
        @{Label = "Pool`n[Region]";                  Expression = {($_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.PoolName) [$($_.Region)]"}) -join " & "}},
        @{Label = "Quote`nTimestamp(s)";             Expression = {($_.Pools.PSObject.Properties.Value | ForEach-Object {($_.Updated.ToString("dd.MM.yyyy HH:mm:ss"))}) -join "|"}},
        @{Label = "Info";                            Expression = {($_.Pools.PSObject.Properties.Value | ForEach-Object {$_.Info}) -join " "}}
    ) | Out-Host

    if (-not $DisplayProfitOnly) {
        # Begin UselessGuru: Display active miners list only when mining
        $ActiveMiners | Where-Object Activated -GT 0 | Sort-Object -Descending Status, {if ($_.Process -eq $null) {[DateTime]0}else {$_.Process.StartTime}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
            @{Label = "Speed"; Expression = {$_.Speed_Live.PSObject.Properties.Value | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
            @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $(if ($_.Process -eq $null) {$_.Active}else {if ($_.Process.ExitTime -gt $_.Process.StartTime) {($_.Active + ($_.Process.ExitTime - $_.Process.StartTime))}else {($_.Active + ((Get-Date) - $_.Process.StartTime))}})}}, 
            @{Label = "Launched"; Expression = {Switch ($_.Activated) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
            @{Label = "API Port"; Expression = {$_.Port}}, 
            @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
        ) | Out-Host
    }
    # End UselessGuru: Display active miners list

    #Display profit comparison
    if ($DisplayComparison) { # UselessGuru: Support for $DisplayComparison
        if (($BestMiners_Combo | Where-Object Profit -EQ $null | Measure-Object).Count -eq 0 -and $Downloader.State -ne "Running") {
            $MinerComparisons = 
            [PSCustomObject]@{"Miner" = "MultiPoolMiner"}, 
            [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object {"$($_.Name)-$($_.Algorithm -join "/")"}}

            $BestMiners_Combo_Stat = Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure-Object Profit -Sum).Sum -Duration $StatSpan

            $MinerComparisons_Profit = $BestMiners_Combo_Stat.Week, ($BestMiners_Combo_Comparison | Measure-Object Profit_Comparison -Sum).Sum

            $MinerComparisons_MarginOfError = $BestMiners_Combo_Stat.Week_Fluctuation, ($BestMiners_Combo_Comparison | ForEach-Object {$_.Profit_MarginOfError * (& {if ($MinerComparisons_Profit[1]) {$_.Profit_Comparison / $MinerComparisons_Profit[1]}else {1}})} | Measure-Object -Sum).Sum

            $Currency | ForEach-Object {
                $MinerComparisons[0] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[0] * $Rates.$_), $MinerComparisons_MarginOfError[0], (($MinerComparisons_Profit[0] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[0])), (($MinerComparisons_Profit[0] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[0])))
                $MinerComparisons[1] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[1] * $Rates.$_), $MinerComparisons_MarginOfError[1], (($MinerComparisons_Profit[1] * $Rates.$_) / (1 + $MinerComparisons_MarginOfError[1])), (($MinerComparisons_Profit[1] * $Rates.$_) * (1 + $MinerComparisons_MarginOfError[1])))
            }

            if ([Math]::Round(($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1], 2) -gt 0) {
                $MinerComparisons_Range = ($MinerComparisons_MarginOfError | Measure-Object -Average | Select-Object -ExpandProperty Average), (($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1]) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
                Write-Host -BackgroundColor Yellow -ForegroundColor Black "MultiPoolMiner is between $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])-$MinerComparisons_Range)*100)))% and $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])+$MinerComparisons_Range)*100)))% more profitable than the fastest miner: "
            }

            $MinerComparisons | Out-Host
        }
    } # UselessGuru: Support for $DisplayComparison
    
    # Begin UselessGuru: Profit summary
    if ($UseDopeColoring) {
        $ProfitSummary = "$(($Profits * $Rates.$($Currency[0])).ToString("N2")) $($Currency[0].ToUpper()) ($(($Earnings * $Rates.$($Currency[0])).ToString("N2"))-$(($PowerCosts * $Rates.$($Currency[0])).ToString("N2")))"
        if (-not $BenchmarkMode) {
            if ($MiningIsProfitable) {Write-Host -ForegroundColor Black -BackgroundColor Green -NoNewline "Mining selected algorithms is profitable!"; Write-Host -ForegroundColor Yellow -NoNewline " Estimated daily earnings:"; Write-Host -ForegroundColor Green " $($ProfitSummary)"}
            elseif (-not $DisplayProfitOnly) {Write-Log -Level Warn "Mining is currently NOT profitable - mining stopped! According to pool pricing information currently mining $($ProfitSummary)"}
        }
        Write-Host -ForegroundColor DarkMagenta -NoNewline "Profitability limit: "; Write-Host -ForegroundColor DarkGreen -NoNewline "$($MinProfit.ToString("N2")) "; Write-Host -ForegroundColor DarkYellow -NoNewline "$($Currency[0].ToUpper())"; Write-Host -ForegroundColor Gray -NoNewline "/"; Write-Host -ForegroundColor DarkMagenta -NoNewline "day"; Write-Host -ForegroundColor DarkGray -Nonewline "  |  "; Write-Host -ForegroundColor DarkRed -NoNewline "Electricity rate: "; Write-Host -ForegroundColor Red -NoNewline "$($PowerPricePerKW.ToString("N2")) "; Write-Host -ForegroundColor DarkYellow -NoNewline "$($Currency[0].ToUpper())"; Write-Host -ForegroundColor Gray -NoNewline "/"; Write-Host -ForegroundColor DarkRed -NoNewline "kWh"; Write-Host -ForegroundColor DarkGray -Nonewline "  |  "; Write-Host -ForegroundColor Cyan -NoNewline "$($Rates.$($Currency[0]).ToString("N2")) "; Write-Host -ForegroundColor DarkYellow -NoNewline "$($Currency[0].ToUpper())"; Write-Host -ForegroundColor Gray -NoNewline "/"; Write-Host -ForegroundColor Cyan "BTC"
    }
    else {
        $ProfitSummary = "$(($Profits * $Rates.$($Currency[0])).ToString("N2")) $($Currency[0].ToUpper())/day ($(($Earnings * $Rates.$($Currency[0])).ToString("N2")) - $(($PowerCosts * $Rates.$($Currency[0])).ToString("N2")) $($Currency[0].ToUpper())/day). "
        if (-not $BenchmarkMode) {
            if ($MiningIsProfitable) {Write-Host "Mining is currently profitable using the algorithms listed above. According to pool pricing information currently mining $($ProfitSummary)"}
            elseif (-not $DisplayProfitOnly) {Write-Log -Level Warn -Message "Mining is currently NOT profitable - mining stopped! According to pool pricing information currently mining $($ProfitSummary)"}
        }
        Write-Host "(Profitability limit: $($MinProfit.ToString("N2")) $($Currency[0].ToUpper())/day; Power cost $($PowerPricePerKW.ToString("N2")) $($Currency[0].ToUpper())/kW; 1 BTC = $($Rates.$($Currency[0]).ToString("N2")) $($Currency[0].ToUpper())). "
    }
    
    if ($BenchmarkMode -and -not $DisplayProfitOnly) {Write-Host  -BackgroundColor Yellow -ForegroundColor Black "Benchmarking - do not execute GPU intense applications until benchmarking is complete!"}
    if (-not $BenchmarkMode -and $DisplayProfitOnly) {Write-Host  -BackgroundColor Yellow -ForegroundColor Black "DisplayProfitOnly - will not run any miners!"}

    # End UselessGuru: Profit summary
    
    #Reduce Memory
    Get-Job -State Completed | Remove-Job
    [GC]::Collect()

    $CrashedMiners = @()
    #Do nothing for a few seconds as to not overload the APIs and display miner download status
    Write-Log -Message "Waiting to start next run" <# UselessGuru #>
    for ($i = $Strikes; $i -gt 0 -or $Timer -lt $StatEnd; $i--) {
        if ($MiningIsProfitable -or $BenchmarkMode) {
            $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
                if (-not $_.Process.name -or ($_.Process.HasExited) -and -not $DisplayProfitOnly ) {
                    $CrashedMiners += $_
                }
            }
            if ($CrashedMiners) {
                $CrashedMiners | Where-Object Status -ne "Crashed" | ForEach-Object {
                    $_.Status = "Crashed"
                    Write-Log -Level Error "$($_.Type) Miner '$($_.Name)' ($($_.Algorithm -join '|')) [GPU Devices: $($_.Index)] crashed: '$(Split-Path $_.Path -leaf) $($_.Arguments)'"
                }
                if ($BeepOnError) {[console]::beep(2000,500)}
            }
            if ($DisplayProfitOnly -or $CrashedMiners.count -gt 0) {break}
        }
        if ($Downloader) {$Downloader | Receive-Job}
        Start-Sleep 10
        $Timer = (Get-Date).ToUniversalTime()
    }

    if (-not $DisplayProfitOnly) {

        #Save current hash rates
        if ($UseJobsForGetData -and ($ActiveMiners | Where-Object Best -EQ $true).count -gt 1) {
            $ActiveMiners | ForEach-Object {
                $Miner = $_

                if ($Miner.New) {$Miner.Benchmarked++}

                if ($Miner.Process -and -not $Miner.Process.HasExited -and $Miner.Port) {
                    Write-Log -Message "Starting job requesting stats from $($_.Type) miner '$($_.Name)' ($($_.Algorithm -join '|')) [GPU Devices: $($_.Index); API: $($Miner.API); Port: $($Miner.Port)]... "
                    
                    Start-Job -Name "GetMinerData_$($Miner.Name)" ([scriptblock]::Create("Set-Location('$(Get-Location)');. 'APIs\$($Miner.API).ps1'")) -ArgumentList ($Miner, $Strikes) -ScriptBlock {
                        param($Miner, $Strikes)
                        $MinerObject = New-Object $Miner.API -Property @{
                            Name                 = $Miner.Name
                            Path                 = $Miner.Path
                            Arguments            = $Miner.Arguments
                            Wrap                 = $Miner.Wrap
                            API                  = $Miner.API
                            Port                 = $Miner.Port
                            Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
                            Type                 = $Miner.Type
                            Index                = $Miner.Index
                            Device               = $Miner.Device
                            Device_Auto          = $Miner.Device_Auto
                            Earning              = $Miner.Earning
                            Profit               = $Miner.Profit
                            Profit_Comparison    = $Miner.Profit_Comparison
                            Profit_MarginOfError = $Miner.Profit_MarginOfError
                            Profit_Bias          = $Miner.Profit_Bias
                            Speed                = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
                            #Speed_Live           = $Miner.Speed_Live
                            Best                 = $Miner.Best
                            Best_Comparison      = $Miner.Best_Comparison
                            Process              = $Miner.Process
                            New                  = $Miner.New
                            Active               = $Miner.Active
                            Activated            = $Miner.Activated
                            Status               = $Miner.Status
                            Benchmarked          = $Miner.Benchmarked
                            PowerDraw            = $Miner.PowerDraw # Power consumption of all cards for this miner
                            PowerCost            = $Miner.PowerCost # = Total power draw  * $PowerPricePerKW
                            ComputeUsage         = $Miner.ComputeUsage
                            Pool                 = $Miner.Pool
                        }
                        $MinerObject.GetData($Miner.Algorithm, ($Miner.New -and $Miner.Benchmarked -lt $Strikes))
                    } | Out-Null
                }
            }
            
            Write-Log -Message "Waiting for stats job(s) from miner(s) to complete - max. $($Strikes * $Interval) seconds... "
            Get-Job -Name "GetMinerData_*" | Wait-Job -Timeout ($Strikes * $Interval) | Out-Null
            
            $ActiveMiners | Where-Object {$_.Process -and -not $_.Process.HasExited -and $_.Port} | ForEach-Object {
                $Miner = $_
                $Miner_Name = $Miner.Name
                $Miner.Speed_Live = 0
                $Miner_HashRate = [PSCustomObject]@{}

                $Miner_Data = Receive-Job -Name "GetMinerData_$($Miner_Name)"
                
                if ($Miner_Data) {
                    # Update hash rate, gpu and power stats
                    Update-Stats $Miner $Miner_Data $StatSpan
                }
                else {
                    if ($Miner_Name -notmatch "PalginNvidia.*" <# temp fix, Palgin does not have an APi yet#>) {
                        if ($BeepOnError) {
                            [console]::beep(1000,500)
                        }
                        Write-Log -Level Error "Failed to connect to $($Miner.Type) miner '$($Miner.Name)' ($($Miner.Algorithm -join '|')) [GPU Devices: $($Miner.Index)]. "
                    }
                }
            }

            #Reduce Memory
            Get-Job -State Completed | Remove-Job
            [GC]::Collect()
        }
        else {
            $ActiveMiners | ForEach-Object {
                $Miner = $_
                $Miner.Speed_Live = 0
                $Miner_HashRate = [PSCustomObject]@{}

                if ($Miner.New) {$Miner.Benchmarked++}

                if ($Miner.Process -and -not $Miner.Process.HasExited) {

                    Write-Log -Message "Requesting stats for $($_.Type) miner '$($Miner.Name)' ($($_.Algorithm -join '|')) [GPU Devices: $($Miner.Index); API: $($Miner.API); Port: $($Miner.Port)]... "

                    $Miner_Data = ($Miner.GetData($Miner.Algorithm, ($Miner.New -and $Miner.Benchmarked -lt $Strikes)))
                    $Miner.Speed_Live = $Miner_Data.HashRate.PSObject.Properties.Value
                   
                    # Update hasrate, gpu and powerstats
                    Update-Stats $Miner $Miner_Data $StatSpan
                }
            }
        }
        #Benchmark timeout
        if ($Miner.Benchmarked -ge ($Strikes * $Strikes) -or ($Miner.Benchmarked -ge $Strikes -and $Miner.Activated -ge $Strikes)) {
            $Miner.Algorithm | Where-Object {-not $Miner_HashRate.$_} | ForEach-Object {
                if ((Get-Stat "$($Miner.Name)_$($_)_HashRate") -eq $null) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Value 0 -Duration $StatSpan
                }
            }
        }
    }
}

#Stop the log
Stop-Transcript