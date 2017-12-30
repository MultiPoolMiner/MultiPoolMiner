using module .\Include.psm1

param(
    [Parameter(Mandatory = $false)][String]$Wallet = "1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF", 
    [Parameter(Mandatory = $false)][String]$UserName="UselessGuru", 
    [Parameter(Mandatory = $false)][String]$WorkerName = "Blackbox", 
    [Parameter(Mandatory = $false)][String]$Password = "x", 
    [Parameter(Mandatory = $false)][Int]$API_ID = 0, 
    [Parameter(Mandatory = $false)][String]$API_Key = "", 
    [Parameter(Mandatory = $false)][Int]$Interval = 60, #seconds before reading hash rate from miners
    [Parameter(Mandatory = $false)][String]$Region = "europe", #europe/us/asia
    [Parameter(Mandatory = $false)][Switch]$SSL = $false, 
    [Parameter(Mandatory = $false)][Array]$Type = @("AMD","NVIDIA","CPU"), #AMD/NVIDIA/CPU
    [Parameter(Mandatory = $false)][Array]$Algorithm = @(), #i.e. Ethash,Equihash,CryptoNight etc.
    [Parameter(Mandatory = $false)][Array]$MinerName = @(), 
    [Parameter(Mandatory = $false)][Array]$PoolName = @(), 
    [Parameter(Mandatory = $false)][Array]$ExcludeAlgorithm = @(), #i.e. Ethash,Equihash,CryptoNight etc.
    [Parameter(Mandatory = $false)][Array]$ExcludeMinerName = @(), 
    [Parameter(Mandatory = $false)][Array]$ExcludePoolName = @(),
    [Parameter(Mandatory = $false)][Array]$Currency = ("CHF","BTC","USD"), #i.e. GBP,EUR,ZEC,ETH etc.
    [Parameter(Mandatory = $false)][Int]$Donate = 24, #Minutes per Day
    [Parameter(Mandatory = $false)][String]$Proxy = "", #i.e http://192.0.0.1:8080
    [Parameter(Mandatory = $false)][Int]$Delay = 0, #seconds before opening each miner
    [Parameter(Mandatory = $false)][Switch]$Watchdog = $false,
    [Parameter(Mandatory = $false)][String]$MinerStatusURL = "http://mining.emsley.ca/miner.php",
    [Parameter(Mandatory = $false)][Int]$SwitchingPrevention = 1, #zero does not prevent miners switching,
    [Parameter(Mandatory = $false)][String]$MinerWindowStyle = "Minimized", # Any of: '"normal","maximized","minimized","hidden". Note: During benchmark all windows will run in "normal" mode. Hidden is not supported for wrapper
    [Parameter(Mandatory = $false)][String]$PayoutCurrency = "BTC", #i.e. BTH,ZEC,ETH etc., if supported by the pool mining earnings will be autoconverted and paid out in this currency
    [Parameter(Mandatory = $false)][Double]$MinProfit = 1,  # Minimal required profit (in $Currency[0]), if less it will not mine
    [Parameter(Mandatory = $false)][Double]$PowerPricePerKW = 0.3, # Electricity price per kW (in $currency[0]), 0 will disable power cost calculation
    [Parameter(Mandatory = $false)][Double]$Computer_PowerDraw = 50, # Base power consumption of computer (in Watts) excluding GPUs or CPU mining
    [Parameter(Mandatory = $false)][Double]$CPU_PowerDraw = 80, # Power consumption (in Watts) of all CPUs when mining (on top of general power ($Computer_PowerConsumption) needed to run your computer when NOT mining) (in $currency[0])
    [Parameter(Mandatory = $false)][Double]$GPU_PowerDraw = 500, # Power consumption of all GPUs when mining (in $currency[0])
    [Parameter(Mandatory = $false)][Switch]$DisplayProfitOnly = $false, # If $true will not start miners and list hypthetical earnings
    [Parameter(Mandatory = $false)][Switch]$DisplayComparison = $false, # If $true will evaluate and display MPM miner is faster than... in summary, if $false will save CPU cycles and screen space
    [Parameter(Mandatory = $false)][Switch]$UseShortPoolNames = $true, # If $true will display short pool names in summary
    [Parameter(Mandatory = $false)][Switch]$DeviceSubTypes = $false, # If true separate miners will be launched for each GPU model class$
    [Parameter(Mandatory = $false)][Int]$MinPoolWorkers = 10, # Minimum workers required to mine on coin, if less skip the coin
    [Parameter(Mandatory = $false)][Switch]$ProfitLessFee = $true, # If true profit = earnings - less pool fees
    [Parameter(Mandatory = $false)][String]$PriceTimeSpan, # Week, Day, Hour, Minute_10, Minute_5
    [Parameter(Mandatory = $false)][Switch]$BeepOnError=$true # if $true will beep on errors
)

$progressPreference = 'silentlyContinue' 

if ($PGHome -notmatch ".+") {Clear-Host}

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}
if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

if ($Proxy -eq "") {$PSDefaultParameterValues.Remove("*:Proxy")}
else {$PSDefaultParameterValues["*:Proxy"] = $Proxy}

# . .\Invoke-CreateProcess.ps1

$ExcludeAlgorithm = $ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_}
$Region = $Region | ForEach-Object {Get-Region $_}
$GPUsFalse = (Get-GPUdevices $Type $false)
$GPUsTrue = (Get-GPUdevices $Type $true)
$GPUs = (Get-GPUdevices $Type $DeviceSubTypes)

$Strikes = 3

$Timer = (Get-Date).ToUniversalTime()

$StatEnd = $Timer

$DecayStart = $Timer
$DecayPeriod = 60 #seconds
$DecayBase = 1 - 0.1 #decimal percentage

$WatchdogInterval = $Interval * $Strikes
$WatchdogReset = $Interval * $Strikes * $Strikes * $Strikes

$WatchdogTimers = @()

$ActiveMiners = @()

$Rates = [PSCustomObject]@{BTC = [Double]1}

#Start the log
Start-Transcript ".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

#Check for software updates
#$Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList ("6.1", $PSVersionTable.PSVersion, "") -FilePath .\Updater.ps1

#Set donation parameters
if ($Donate -lt 10) {$Donate = 10}
$LastDonated = $Timer.AddDays(-1).AddHours(1)
$WalletDonate = @("1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb", "1Fonyo1sgJQjEzqp1AxgbHhGkCuNrFt6v9")[[Math]::Floor((Get-Random -Minimum 1 -Maximum 11) / 10)]
$UserNameDonate = @("aaronsace", "fonyo")[[Math]::Floor((Get-Random -Minimum 1 -Maximum 11) / 10)]
$WorkerNameDonate = "multipoolminer"
$WalletBackup = $Wallet
$UserNameBackup = $UserName
$WorkerNameBackup = $WorkerName

while ($true) {
    Get-ChildItem "APIs" | ForEach-Object {. $_.FullName}

    $Timer = (Get-Date).ToUniversalTime()

    $StatStart = $StatEnd
    $StatEnd = $Timer.AddSeconds($Interval)
    $StatSpan = New-TimeSpan $StatStart $StatEnd

    $DecayExponent = [int](($Timer - $DecayStart).TotalSeconds / $DecayPeriod)

    $WatchdogInterval = ($WatchdogInterval / $Strikes * ($Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Strikes * $Strikes * $Strikes) * (($Strikes * $Strikes * $Strikes) - 1)) + $StatSpan.TotalSeconds

#    #Activate or deactivate donation
#    if ($Timer.AddDays(-1).AddMinutes($Donate) -ge $LastDonated) {
#        if ($Wallet) {$Wallet = $WalletDonate}
#        if ($UserName) {$UserName = $UserNameDonate}
#        if ($WorkerName) {$WorkerName = $WorkerNameDonate}
#    }
#    if ($Timer.AddDays(-1) -ge $LastDonated) {
#        $Wallet = $WalletBackup
#        $UserName = $UserNameBackup
#        $WorkerName = $WorkerNameBackup
#        $LastDonated = $Timer
#    }

    #Update the exchange rates
    try {
        $NewRates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
        $Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Rates | Add-Member $_ ([Double]$NewRates.$_) -Force}
    }
    catch {
        Write-Warning "Coinbase is down. "
    }

    # By default mining is NOT profitable
    [Switch]$MiningIsProfitable = $false

    #Load the stats
    $Stats = [PSCustomObject]@{}
    if (Test-Path "Stats") {Get-ChildItemContent "Stats" | ForEach-Object {$Stats | Add-Member $_.Name $_.Content}}

    if (-not $CrashedMiners) {
        #Load information about the pools
        "Loading available pools..." | Out-Host
        $NewPools = @()
        if (Test-Path "Pools") {
            $NewPools = Get-ChildItemContent "Pools" -Parameters @{Wallet = $Wallet; UserName = $UserName; Password = $Password; WorkerName = $WorkerName; StatSpan = $StatSpan; Algorithm = $Algorithm; PayoutCurrency = $PayoutCurrency; ProfitLessFee = $ProfitLessFee; MinPoolWorkers = $MinPoolWorkers; UseShortPoolNames = $UseShortPoolNames} | ForEach-Object {$_.Content | Add-Member Name $_.Name -Force -PassThru}
        }    
        $AllPools = @($NewPools) + @(Compare-Object @($NewPools | Select-Object -ExpandProperty Name -Unique) @($AllPools | Select-Object -ExpandProperty Name -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$AllPools | Where-Object Name -EQ $_}) | 
            Where-Object {$Algorithm.Count -eq 0 -or (Compare-Object $Algorithm $_.Algorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
            Where-Object {$ExcludeAlgorithm.Count -eq 0 -or (Compare-Object $ExcludeAlgorithm $_.Algorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}

        #Remove non-present pools
    $AllPools = $AllPools | Where-Object {Test-Path "Pools\$($_.Name).ps1"}

        #Apply watchdog to pools
        $AllPools = $AllPools | Where-Object {
            $Pool = $_
            $Pool_WatchdogTimers = $WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset)
            ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
        }

        #Update the active pools
        if ($AllPools.Count -eq 0) {
            Write-Warning "No pools available. "
            if ($Downloader) {$Downloader | Receive-Job}
            Start-Sleep $Interval
            continue
        }
        $Pools = [PSCustomObject]@{}
        $AllPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($AllPools | Sort-Object -Descending {$PoolName.Count -eq 0 -or (Compare-Object $PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}, {$_.StablePrice * (1 - $_.MarginOfError)}, {$_.Region -EQ $Region}, {$_.SSL -EQ $SSL} | Where-Object Algorithm -EQ $_ | Select-Object -First 1)}
        if (($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_} | Measure-Object Updated -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalSeconds) -gt $Interval * $Strikes) {
            Write-Warning "Pool prices are out of sync. "
            $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Bias ($Pools.$_.StablePrice * (1 - ($Pools.$_.MarginOfError * $SwitchingPrevention * [Math]::Pow($DecayBase, $DecayExponent)))) -Force}
        }
        else {
            $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_ | Add-Member Price_Bias ($Pools.$_.Price * (1 - ($Pools.$_.MarginOfError * $SwitchingPrevention * [Math]::Pow($DecayBase, $DecayExponent)))) -Force}
        }
    }
    $BenchmarkMode = $false

    #Load information about the miners
    "Loading available miners..." | Out-Host
    #Messy...?
    $AllMiners = if (Test-Path "Miners") {
        Get-ChildItemContent "Miners" -Parameters @{Pools = $Pools; Stats = $Stats; StatSpan = $StatSpan; GPUs = $GPUs} | ForEach-Object {$_.Content | Add-Member Name $_.Name -Force -PassThru} | 
        Where-Object {$Type.Count -eq 0 -or (Compare-Object $Type $_.Type -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {($Algorithm.Count -eq 0 -or (Compare-Object $Algorithm $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0) -and ((Compare-Object $Pools.PSObject.Properties.Name $_.HashRates.PSObject.Properties.Name | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0)} | 
        Where-Object {$ExcludeAlgorithm.Count -eq 0 -or (Compare-Object $ExcludeAlgorithm $_.HashRates.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | 
        Where-Object {$MinerName.Count -eq 0 -or (Compare-Object $MinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
        Where-Object {$ExcludeMinerName.Count -eq 0 -or (Compare-Object $ExcludeMinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0}
    }
    $AllMiners | ForEach-Object {
        $Miner = $_

        # Default ComputeUsage (in %, 100 = max))
        if ($Miner.ComputeUsage -eq $null -or $Miner.ComputeUsage -eq "") {
            $Miner | Add-Member ComputeUsage 100 -Force
        }
        $Miner.ComputeUsage = [Double]$Miner.ComputeUsage
        
        # Default power consumption, force BenchmarkMode
        if (-not $Miner.PowerDraw -gt 0) {
            $Miner | Add-Member PowerDraw 0 -Force
            $Miner.HashRates.PSObject.Properties.Name | ForEach-Object {
                $Miner.HashRates.$_ = $null
                $BenchmarkMode = $true
            }
        }

        if ($PowerPricePerKW -gt 1E-11) {
            # Convert power cost back to BTC, all profit calculations are done in BTC
            $Miner_PowerCost = [Double](([Double]$Miner.PowerDraw + [Double]($Computer_PowerDraw / $GPUs.Device.Count)) / 1000 * 24 * [Double]$PowerPricePerKW / $Rates.$($Currency[0]))
        }
        else {
            $Miner_PowerCost = 0
        }
        $Miner | Add-Member PowerCost $Miner_PowerCost -Force

        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Earnings = [PSCustomObject]@{}
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
            $Miner_Earnings | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price)
            $Miner_Profits | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price - $Miner_PowerCost)
            $Miner_Profits_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice - $Miner_PowerCost)

            $Miner_Profits_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Bias)
        }

        $Miner_Earning = [Double]($Miner_Earnings.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit = [Double]($Miner_Profits.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Comparison = [Double](($Miner_Profits_Comparison.PSObject.Properties.Value | Measure-Object -Sum).Sum - $Miner_PowerCost)
        $Miner_Profit_Bias = [Double]($Miner_Profits_Bias.PSObject.Properties.Value | Measure-Object -Sum).Sum

        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            $Miner_Profits_MarginOfError | Add-Member $_ ([Double]$Pools.$_.MarginOfError * (& {if ($Miner_Profit) {([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice) / $Miner_Profit}else {1}}))
        }

        $Miner_Profit_MarginOfError = [Double]($Miner_Profits_MarginOfError.PSObject.Properties.Value | Measure-Object -Sum).Sum

        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            if (-not [String]$Miner.HashRates.$_) {
                $BenchmarkMode = $true
                $Miner_HashRates.$_ = $null
                $Miner_Profits.$_ = $null
                $Miner_Profits_Comparison.$_ = $null
                $Miner_Profits_Bias.$_ = $null
                $Miner_Earning = $null
                $Miner_Profit = $null
                $Miner_Profit_Comparison = $null
                $Miner_Profits_MarginOfError = $null
                $Miner_Profit_Bias = $null
            }
        }

        if ($Miner_Types -eq $null) {$Miner_Types = $AllMiners.Type | Select-Object -Unique}
        if ($Miner_Indexes -eq $null) {$Miner_Indexes = $AllMiners.Index | Select-Object -Unique}

        if ($Miner_Types -eq $null) {$Miner_Types = ""}
        if ($Miner_Indexes -eq $null) {$Miner_Indexes = -1}

        $Miner.HashRates = $Miner_HashRates

        $Miner | Add-Member Pools $Miner_Pools
        $Miner | Add-Member Earnings $Miner_Earnings
        $Miner | Add-Member Profits $Miner_Profits
        $Miner | Add-Member Profits_Comparison $Miner_Profits_Comparison
        $Miner | Add-Member Profits_Bias $Miner_Profits_Bias
        $Miner | Add-Member Earning $Miner_Earning
        $Miner | Add-Member Profit $Miner_Profit
        $Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
        $Miner | Add-Member Profit_MarginOfError $Miner_Profit_MarginOfError
        $Miner | Add-Member Profit_Bias $Miner_Profit_Bias
    
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
    
    # Open firewall ports for all miners    
    if (Get-Command "Get-NetFirewallRule" -ErrorAction SilentlyContinue) {
        if ($MinerFirewalls -eq $null) {$MinerFirewalls = Get-NetFirewallApplicationFilter | Select-Object -ExpandProperty Program}
        if (@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ "=>") {
            Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'; ('$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Compress)' | ConvertFrom-Json) | ForEach {New-NetFirewallRule -DisplayName 'MultiPoolMiner' -Program `$_}" -replace '"', '\"') -Verb runAs
            $MinerFirewalls = $null
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
        Write-Warning "No miners available. "
        if ($Downloader) {$Downloader | Receive-Job}
        if ($DisplayProfitOnly) {Start-Sleep ($Interval / 10)} else {Start-Sleep $Interval}
        continue
    }
    $ActiveMiners | ForEach-Object {
        $_.Earning = 0
        $_.Profit = 0
        $_.Profit_Comparison = 0
        $_.Profit_MarginOfError = 0
        $_.Profit_Bias = 0
        $_.Best = $false
        $_.Best_Comparison = $false
    }
    $Miners | ForEach-Object {
        $Miner = $_
        $ActiveMiner = $ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and 
            $_.Path -eq $Miner.Path -and 
            $_.Arguments -eq $Miner.Arguments -and
            $_.Wrap -eq $Miner.Wrap -and 
            $_.API -eq $Miner.API -and 
            #$_.Port -eq $Miner.Port -and # removed, dynamic ports!
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }
        if ($ActiveMiner) {
            $ActiveMiner.Type = $Miner.Type
            $ActiveMiner.Index = $Miner.Index
            $ActiveMiner.Device = $Miner.Device
            $ActiveMiner.Device_Auto = $Miner.Device_Auto
            $ActiveMiner.Earning = $Miner.Earning
            $ActiveMiner.Profit = $Miner.Profit
            $ActiveMiner.Profit_Comparison = $Miner.Profit_Comparison
            $ActiveMiner.Profit_MarginOfError = $Miner.Profit_MarginOfError
            $ActiveMiner.Profit_Bias = $Miner.Profit_Bias
            $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
            $ActiveMiner.PowerDraw = [Double]$Miner.PowerDraw
            $ActiveMiner.ComputeUsage = [Double]$Miner.ComputeUsage
            $ActiveMiner.Pool = $Miner.Pool
            if ($Miner.Status) {$ActiveMiner.Status = $Miner.Status}
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
                Earning              = $Miner.Earning
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
                PowerDraw            = $Miner.PowerDraw
                PowerCost            = $Miner.PowerCost
                ComputeUsage         = $Miner.ComputeUsage
                Pool                 = $Miner.Pool
             }
        }
    }

    $ActiveMiners | Where-Object Device_Auto | ForEach-Object {
        $Miner = $_
        $Miner.Device = ($Miners | Where-Object {(Compare-Object $Miner.Type $_.Type -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}).Device | Select-Object -Unique | Sort-Object
        if ($Miner.Device -eq $null) {$Miner.Device = ($Miners | Where-Object {(Compare-Object $Miner.Type $_.Type -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}).Type | Select-Object -Unique | Sort-Object}
    }

    #Don't penalize active miners
    $ActiveMiners | Where-Object Status -EQ "Running" | ForEach-Object {$_.Profit_Bias = $_.Profit}

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $ActiveMiners | Select-Object Type, Index -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Type $_.Type | Measure-Object).Count -eq 0 -and (Compare-Object $Miner_GPU.Index $_.Index | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)}
    $BestDeviceMiners = $ActiveMiners | Select-Object Device -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Device $_.Device | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)}
    $BestMiners_Comparison = $ActiveMiners | Select-Object Type, Index -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Type $_.Type | Measure-Object).Count -eq 0 -and (Compare-Object $Miner_GPU.Index $_.Index | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)}
    $BestDeviceMiners_Comparison = $ActiveMiners | Select-Object Device -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Device $_.Device | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)}
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
    if ($DisplayComparison) {
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
    }
    if ($ActiveMiners.Count -gt 1) {
        $BestMiners_Combo = $BestMiners_Combos | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Bias -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination
        if ($DisplayComparison) {$BestMiners_Combo_Comparison = $BestMiners_Combos_Comparison | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Comparison -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination}
    }
    else {
        $BestMiners_Combo = $ActiveMiners
        if ($DisplayComparison) {$BestMiners_Combo_Comparison = $ActiveMiners}
    }

    $BestMiners_Combo | ForEach-Object {$_.Best = $true}
    if ($DisplayComparison) {$BestMiners_Combo_Comparison | ForEach-Object {$_.Best_Comparison = $true}}

    $Earnings= 0
    $Profits = 0
    $PowerCosts = 0
    $ActiveMiners | Select-Object Device -Unique | ForEach-Object {$Miner_GPU = $_; ($ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.Device $_.Device | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1)} | ForEach-Object {
        $Earnings += $_.Earning
        $Profits += $_.Profit
        $PowerCosts += $_.PowerCost
    }
    $MiningIsProfitable = ($Profits * $Rates.$($Currency[0])) -ge $MinProfit

    #Stop or start miners in the active list depending on if they are the most profitable
    if ($MiningIsProfitable -or $BenchmarkMode) {
        $KeepOldMinerRunning = 0
        $DAGDownloadDelay = 0

        $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
            if ($DisplayProfitOnly) {
                $_.Status = "Running"
                $_.Process = "DisplayProfitOnly"
                $_.Activated++
            }
            else {
                if ($_.Process -eq $null -or $_.Process.HasExited -ne $false) {
                    $Miner_Command = "$(Split-Path $_.Path -leaf) $($_.Arguments)"
                    "$(Split-Path $_.Path -leaf) $($_.Arguments)" | Out-File "$(Split-Path $_.Path)\$($_.Name)_$($($_.Algorithm | ForEach-Object { (($_)+ "_" + $Pools.$_.Name)}) -join "-").cmd" -Encoding default
                    $DecayStart = $Timer
                    $_.New = $true
                    $_.Activated++
                    if ($_.Process -ne $null) {$_.Active += $_.Process.ExitTime - $_.Process.StartTime}
                    if ($BenchmarkMode) {$ShowWindow = "SW_SHOWNORMAL"; $WindowStyle = "Normal"} else {$ShowWindow = "SW_SHOWMINNOACTIVE"; $WindowStyle = "$MinerWindowStyle"}
                    $ForegroundWindow = Get-ForegroundWindow
                    if ($_.Wrap) {
                        $_.Process = Start-Process -FilePath (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($_.Port)' -FilePath '$($_.Path)' -ArgumentList '$($_.Arguments)' -WorkingDirectory '$(Split-Path $_.Path)' -ShowWindow '$ShowWindow' -CreationFlags 'CREATE_NEW_CONSOLE' -ForegroundWindowID $($ForegroundWindow.ID)" -WindowStyle $WindowStyle -PassThru
                    }
#                    elseif ($_.API -eq "eminer"-or $_.API -eq "Bminer") {
#                        $_.Process = Start-SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path) -Priority ($_.Type | ForEach-Object {if ($_ -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
#                    }
                    else {
#                        $_.Process = Invoke-CreateProcess -Binary $_.Path -Args (" $($_.Arguments)") -CreationFlags CREATE_NEW_CONSOLE -ShowWindow $ShowWindow -StartF STARTF_USESHOWWINDOW -Priority BelowNormal -WorkingDirectory (Split-Path $_.Path)
                        $_.Process = Start-SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path) -Priority ($_.Type | ForEach-Object {if ($_ -eq "CPU") {-2}else {-1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -WindowStyle ($MinerWindowStyle)
                    }
                    if (-not $BenchmarkMode) {
                        # Return focus
                        [Microsoft.VisualBasic.Interaction]::AppActivate($ForegroundWindow.ID) | Out-Null
                    }
                }
                if ($_.Process -eq $null) {$_.Status = "Failed"}
                else {
                    $_.Status = "Running"
                    $_.Process.PriorityClass = "BelowNormal"
                }
                $KeepOldMinerRunning = 3 #Keep running miners alive until new miners are mining (e.g. DAG download is complete
                #Add watchdog timer
                if ($Watchdog -and $_.Profit -ne $null) {
                    $Miner_Name = $_.Name
                    $_.Algorithm | ForEach-Object {
                        $Miner_Algorithm = $_
                        $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                        if (-not $WatchdogTimer) {
                            $WatchdogTimers += [PSCustomObject]@{
                                MinerName	= $Miner_Name
                                PoolName	= $Pools.$Miner_Algorithm.Name
                                Algorithm	= $Miner_Algorithm
                                Kicked		= $Timer
                                Command		= $Miner_Command
                            }
                        }
                    }
                    if ($_.Algorithm -contains "Ethash*") {
                        # Algorithms with DAG download require 10 seconds more
                        $DAGDownloadDelay = 15
                    }
                }

                # Keep old miner running longer if DAG download is required
                $KeepOldMinerRunning = $KeepOldMinerRunning + $DAGDownloadDelay
            }
        }
        if (-not $BenchmarkMode) {
            Start-Sleep $KeepOldMinerRunning # Sleep only once
            $KeepOldMinerRunning = 0
        }
    }
    if ($Downloader) {$Downloader | Receive-Job}
    Start-Sleep $Delay #Wait to prevent BSOD
    $ActiveMiners | Where-Object Activated -GT 0 | Where-Object Best -EQ $false | ForEach-Object {
        $Miner = $_
        if ($Miner.Process -eq $null -or $Miner.Process.HasExited) {
            if ($Miner.Status -eq "Running") {$Miner.Status = "Failed"}
        }
        else {
            if ($_.Process -ne "DisplayProfitOnly") {
                $Miner.Process.PriorityClass = "Normal"
                $Miner.Process.CloseMainWindow() | Out-Null
            }
            $Miner.Status = "Idle"

            #Remove watchdog timer
            $Miner_Name = $Miner.Name
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($WatchdogTimer) {
                    if ($WatchdogTimer.Kicked -lt $Timer.AddSeconds( - $WatchdogInterval)) {
                        $Miner.Status = "Failed"
                    }
                    else {
                        $WatchdogTimers = $WatchdogTimers -notmatch $WatchdogTimer
                    }
                }
            }
        }
    }

    if ($MinerStatusURL -and -not $DisplayProfitOnly) {.\ReportStatus.ps1 -Address $WalletBackup -WorkerName $WorkerNameBackup -ActiveMiners $ActiveMiners -Miners $Miners -MinerStatusURL $MinerStatusURL}
    
    #Display mining information
    if ($Miners -and $PGHome -notmatch ".+") {Clear-Host}

    if ($Poolname) {Write-Host "Selected pool: $($Poolname)"}
    if ($Algorithm) {Write-Host "Selected algorithms: $($Algorithm)"}
    if ($DeviceSubTypes) {$SortAndGroup = "Device"} else {$SortAndGroup = "Type"}
    
    $Miners | Where-Object {$BenchmarkMode -or $DisplayProfitOnly -or ($_.Earning -gt 0) -or ($_.Profit -eq $null)} | Sort-Object -Descending $SortAndGroup, Profit_Bias | Format-Table -GroupBy $SortAndGroup (
        @{Label = "Miner";              Expression = {$_.Name -replace "_$((Get-Culture).TextInfo.ToTitleCase(($_.Device -replace "-", " " -replace "_", " ")) -replace " ")",""}}, 
        @{Label = "Algorithm(s)";       Expression = {($_.HashRates.PSObject.Properties.Name) -join " & "}},
        @{Label = "Profit";             Expression = {$($_.Profit * $Rates.$($Currency[0])).ToString("N5")}; Align='right'},
        @{Label = "Power Cost";         Expression = {"-$(($_.PowerCost * $Rates.$($Currency[0])).ToString("N5"))"}; Align='right'},
        @{Label = "Power Total";		Expression = {"$(($_.PowerDraw + ($Computer_PowerDraw / $GPUs.Device.count)).ToString("N2")) W"}; Align='right'},
        @{Label = "Power GPU [+Base]";  Expression = {"$($_.PowerDraw.ToString("N2")) W [+$($($Computer_PowerDraw / $GPUs.Device.count).ToString("N2")) W]"}; Align='right'},
        @{Label = "Earning";            Expression = {$($_.Earning * $Rates.$($Currency[0])).ToString("N5")}; Align='right'},
        @{Label = "Accuracy";           Expression = {($_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}) -join "|"}; Align = 'right'}, 
        @{Label = "BTC/GH/Day";         Expression = {($_.Pools.PSObject.Properties.Value.Price | ForEach-Object {($_ * 1000000000).ToString("N5")}) -join "+"}; Align = 'right'}, 
        @{Label = "Speed(s)";           Expression = {($_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"} else {"Benchmarking"}}) -join "|"}; Align = 'right'}, 
        @{Label = "GPU Usage";          Expression = {"$($_.ComputeUsage.ToString("N2"))%"}; Align='right'},
        @{Label = "Pool [Region]";      Expression = {($_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.PoolName) [$($_.Region)]"}) -join " & "}},
        @{Label = "Quote Timestamp(s)"; Expression = {($_.Pools.PSObject.Properties.Value | ForEach-Object {($_.Updated.ToString('dd.MM.yyyy HH:mm:ss'))}) -join "|"}},
        @{Label = "Info";               Expression = {($_.Pools.PSObject.Properties.Value | ForEach-Object {$_.Info}) -join " "}}
    ) | Out-Host

    $ProfitSummary = "$(($Profits * $Rates.$($Currency[0])).ToString("N2")) $($Currency[0].ToUpper())/day ($(($Earnings * $Rates.$($Currency[0])).ToString("N2")) - $(($PowerCosts * $Rates.$($Currency[0])).ToString("N2")) $($Currency[0].ToUpper())/day). "
    if ($MiningIsProfitable) {Write-Host "Mining is currently profitable using the algorithms listed above. According to pool pricing information currently mining $($ProfitSummary)"}
    elseif (-not $BenchmarkMode -or -not $DisplayProfitOnly) {Write-Warning "Mining is currently NOT profitable - mining stopped! According to pool pricing information currently mining $($ProfitSummary)"}
    Write-Host "(Profitability limit: $($MinProfit.ToString("N2")) $($Currency[0].ToUpper())/day; Power cost $($PowerPricePerKW.ToString("N2")) $($Currency[0].ToUpper())/kW; 1 BTC = $($Rates.$($Currency[0]).ToString("N2")) $($Currency[0].ToUpper())). "
    
    if ($BenchmarkMode -and -not $DisplayProfitOnly) {Write-Host  -BackgroundColor Yellow -ForegroundColor Black "Benchmarking - do not execute GPU intense applications until benchmarking is complete!"}

    if (-not $BenchmarkMode -and $DisplayProfitOnly) {Write-Host  -BackgroundColor Yellow -ForegroundColor Black "DisplayProfitOnly - will not run any miners!"}

    #Display active miners list
    #    $ActiveMiners | Where-Object Activated -GT 0 | Sort-Object -Descending Status, {if ($_.Process -eq $null) {[DateTime]0}else {$_.Process.StartTime}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
    $ActiveMiners | Where-Object Activated -GT 0 | Sort-Object -Descending Status, $SortAndGroup, {if ($_.Process -eq $null) {[DateTime]0} else {$_.NetProfit}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
        @{Label = "Speed";             Expression = {if ($DisplayProfitOnly) {($_.Speed | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}) -join "|"} else {($_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}) -join "|"}}; Align = 'right'}, 
        @{Label = "Time spent mining"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $(if ($_.Process -eq $null) {$_.Active}else {if ($_.Process.ExitTime -gt $_.Process.StartTime) {($_.Active + ($_.Process.ExitTime - $_.Process.StartTime))}else {($_.Active + ((Get-Date) - $_.Process.StartTime))}})}}, 
        @{Label = "Launched";          Expression = {Switch ($_.Activated) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
        @{Label = "Algorithm(s)";      Expression = {($_.Algorithm) -join " & "}},
        @{Label = "Profit";            Expression = {$($_.Profit * $Rates.$($Currency[0])).ToString("N5")}; Align='right'},
        @{Label = "Earning";           Expression = {$($_.Earning * $Rates.$($Currency[0])).ToString("N5")}; Align='right'},
        @{Label = "Command";           Expression = {($_.Path -ireplace [regex]::Escape($(Convert-Path ".\")), "") + " " + $_.Arguments }}
    ) | Out-Host

    #Display watchdog timers
    $WatchdogTimers | Where-Object Kicked -GT $Timer.AddSeconds( - $WatchdogReset) | Format-Table -Wrap (
        @{Label = "Miner"; Expression = {$_.MinerName}}, 
        @{Label = "Pool"; Expression = {$_.PoolName}}, 
        @{Label = "Algorithm"; Expression = {$_.Algorithm}}, 
        @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'},
        @{Label = "Command"; Expression = {$_.Command}}
    ) | Out-Host

    if ($DisplayComparison) {
        #Display profit comparison
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
    }
    
    #Reduce Memory
    Get-Job -State Completed | Remove-Job
    [GC]::Collect()

    #Do nothing for a few seconds as to not overload the APIs and display miner download status
    $KeyPressed = $null # Press 'L' for next loop
    for ($i = 3; ($i -gt 0 -or $Timer -lt $StatEnd) -and $KeyPressed -ne 'L'; $i--) {
        if ($Downloader) {$Downloader | Receive-Job}

        $CrashedMiners = @()
        if (-not $DisplayProfitOnly -and $MiningIsProfitable) {
            $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
                if (-not $_.Process.name -or ($_.Process.HasExited)) {
                    $CrashedMiners += $_
                }
            }
        }
        
        if (-not $CrashedMiners -or $DisplayProfitOnly) {
            if ($BenchmarkMode) {Start-Sleep 1} else {Start-Sleep 5}
        }

        if ($host.ui.RawUi.KeyAvailable) {
            $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
            $KeyPressed = $Key.character
            while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush
        }
#        switch ($KeyPressed){
#                'L' {break}
#                'C' {$Screen='current'}
#                'H' {$Screen='history'}
#                'E' {$ExitLoop=$true}
#                'W' {$Screen='Wallets'}
#                'U' {if ($Screen -eq "Wallets") {$WalletsUpdate=$null}}
#                'T' {if ($Screen -eq "Profits") {if ($ProfitsScreenLimit -eq 40) {$ProfitsScreenLimit=1000} else {$ProfitsScreenLimit=40}}}
#                'B' {if ($Screen -eq "Profits") {if ($ShowBestMinersOnly -eq $true) {$ShowBestMinersOnly=$false} else {$ShowBestMinersOnly=$true}}}
#        }
        $Timer = (Get-Date).ToUniversalTime()
        if ($CrashedMiners) {
            $CrashedMiners | ForEach-Object {
                Write-Warning "Miner $($_.Name) '$(Split-Path $_.Path -leaf) $($_.Arguments)' crashed!"
                $TimeStamp = Get-Date -format u 
                "$($Timestamp): $(Split-Path $_.Path -leaf) $($_.Arguments)" | Out-File "CrashedMiners.txt" -Append
            }
            [console]::beep(2000,500)
            break
        }
    }

    if (-not $DisplayProfitOnly) {
        #Save current hash rates
        $ActiveMiners | ForEach-Object {
            $Miner = $_

            if ($Miner.New) {$Miner.Benchmarked++}

            if ($Miner.Process -and -not $Miner.Process.HasExited -and $Miner.Port) {
                "Requesting stats for $($Miner.Device) miner... " | Out-Host

                Start-Job -Name "GetMinerData_$($Miner.Device)" ([scriptblock]::Create("Set-Location('$(Get-Location)');. 'APIs\$($Miner.API).ps1'")) -ArgumentList ($Miner, $Strikes) -ScriptBlock {
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
                        Speed_Live           = $Miner.Speed_Live
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
        "Waiting for stats... " | Out-Host
        Get-Job -Name "GetMinerData_*" | Wait-Job -Timeout ($Interval * 2) | Out-Null
        
        $ActiveMiners | ForEach-Object {
            $Miner = $_
            $Miner.Speed_Live = 0
            $Miner_HashRate = [PSCustomObject]@{}

            if ($Miner.Process -and -not $Miner.Process.HasExited -and $Miner.Port) {
                $Miner_Data = Receive-Job -Name "GetMinerData_$($_.Device)"
                if ($Miner_Data) {
                    $Miner_HashRate = $Miner_Data.HashRate
                    $Miner_PowerDraw = $Miner_Data.PowerDraw
                    $Miner_ComputeUsage = $Miner_Data.ComputeUsage
                    $Miner.Speed_Live = $Miner_HashRate.PSObject.Properties.Value
                    "Saving stats for miner $($Miner.Device) [ $(($Miner.Speed_Live) | ConvertTo-Hash)/s | $($Miner_PowerDraw.ToString("N2"))% W  | $($Miner_ComputeUsage.ToString("N2"))% ]... " | Out-Host

                    $Miner.Algorithm | Where-Object {$Miner_HashRate.$_} | ForEach-Object {
                    
                        $Stat = Set-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Value $Miner_HashRate.$_ -Duration $StatSpan -FaultDetection $true

                        #Update watchdog timer
                        $Miner_Name = $Miner.Name
                        $Miner_Algorithm = $_
                        $WatchdogTimer = $WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                        if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                            $WatchdogTimer.Kicked = $Stat.Updated
                        }
                    }
                    $Miner.New = $false
                    # Update power stats
                    if ($Miner_PowerDraw -gt 0) {
                        $Stat = Set-Stat -Name "$($Miner.Name)_$($_.Algorithm -join '')_PowerDraw" -Value $Miner_PowerDraw -Duration $StatSpan -FaultDetection $false
                    }
                    # Update ComputeUsage stats
                    if ($Miner_ComputeUsage -gt 0) {
                        $Stat = Set-Stat -Name "$($Miner.Name)_$($_.Algorithm -join '')_ComputeUsage" -Value $Miner_ComputeUsage -Duration $StatSpan -FaultDetection $false
                    }
                }
                else {
                    if ($BeepOnError) {
                        [console]::beep(1000,500)
                    }
                    Write-Warning "Failed to connect to miner ($($Miner.Name)). "
                }
            }
        }

        #Reduce Memory
        Get-Job -State Completed | Remove-Job
        [GC]::Collect()
    
        #Benchmark timeout
        if ($Miner.Benchmarked -ge ($Strikes * $Strikes) -or ($Miner.Benchmarked -ge $Strikes -and $Miner.Activated -ge $Strikes -and $BenchmarkMode)) {
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