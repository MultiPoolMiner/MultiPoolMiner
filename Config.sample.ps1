# MultiPoolMiner Configuration
#
# Edit the values below and save file as "Config.ps1"
#
# Go to https://multipoolminer.io/docs for detailed information about each setting

######## USER INFORMATION ########

# Your Bitcoin payout address. Required when mining on Zpool, Hash Refinery and Nicehash.
$Wallet = '1GPSq8txFnyrYdXL8t6S94mYdF8cGqVQJF'

# Your username to use to login to MiningPoolHub.
$Username = 'uselessguru'

# Password, for most pools this is not of importance, so just leave the default 
$Password = "x"

# MiningPoolHub API Key from https://miningpoolhub.com/?page=account&action=edit
$API_KEY = 'YOUR_MININGPOOLHUB_API_KEY'

# Choose the default currency or currencies your profit stats will be shown in.
$Currency = @('CHF','BTC','USD','EUR')

######## COMPUTER CONFIGURATION ######## 

# Worker name to show on the mining pools.  Defaults to hostname
$WorkerName = 'BLACKBOX'

# [Europe/US/Asia] Choose your region or the region closest to you.
$Region = 'Europe'
# [NVIDIA,CPU] Choose the relevant GPU(s) and/or CPU mining. AMD currently not supported!
$Type = @('NVIDIA')

# Pools which you prefer to mine on.  All pools are always used if your preferred ones don't support the most profitable algorithm, or your preferred ones are down.
# If left empty, all pools will be treated equally, and it will mine to the most profitable pool at the moment.
# If you really want to completely disable a specific pool, delete it's file from the Pools directory.
$PoolName = @('Nicehash','Zpool','ZpoolCoins')
# Pools you prefer not to mine on. These will be used only as an absolute last resort if your preferred pools are down.
$ExcludePoolName = @()

# Algorithms to mine on this system.  If left empty, all supported algorithms will be used.
# Supported algorithms sorted by pool can be found at https://multipoolminer.io/algorithms
$Algorithm = @('Blake2s','Blakecoin','Decred','Equihash','Groestl','Hsr','Keccak','Lbry','Lyra2RE2','Lyra2z','NeoScrypt','Nist5','Phi','Polytimos','Sib','Skunk','Tribus','Veltor','X17','Xevan')
# If $Algorithm is left empty, it will mine all algorithms EXCEPT the ones listed in $ExcludeAlgorithm
$ExcludeAlgorithm = @()

# Specify miners to only include (restrict to) certain miner applications. A full list of available miners and parameters used can be found here: https://multipoolminer.io/miners
$MinerName = @()
# Exclude certain miners you don't want to use. It is useful if a miner is causing issues with your machine.
$ExcludeMinerName = @()

######## ADVANCED ######## 
# Donation of mining time in minutes per day to aaronsace. Default is 24, minimum is 10 minutes per day (less than 0.7% fee). The downloaded miner software can have their own donation system built in. Check the readme file of the respective miner used for more details.
$Donate = 24
# Enable the watchdog feature which detects and handles miner and other related failures. It works on a unified interval that is defaulted to 60 seconds. Watchdog timers expire if three of those intervals pass without being kicked. There are three stages as to what action is taken when watchdog timers expire and is determined by the number of related expired timers.
$Watchdog = $False
# Enabling SSL will restrict the miner application list to include only the miners that support secure connection.
$SSL = $False
# Specify your proxy address if applicable, i.e http://192.0.0.1:8080
$Proxy = ''
# zero does not prevent miners switching (0 will force MPM to always mine the highest paying algo, not recommended!; 1 and greater: the bigger the number, the less switching
$SwitchingPrevention = 2
# MultiPoolMiner's update interval in seconds. This is a universal timer for running the entire script (downloading/processing APIs, calculation etc). It also determines how long a benchmark is run for each miner file (miner/algorithm/coin). Default is 60.
$Interval = 60
# Specify the number of seconds required to pass before opening each miner. It is useful when cards are more sensitive to switching and need some extra time to recover (eg. clear DAG files from memory)
$Delay = 0
# Send mining status to a URL for monitoring.  This sends information about the miners running on this worker to a remote monitoring web interface
$MinerStatusURL = ''

######## ADVANCED (UselessGuru) ########
# The configuration items in this section are currently not available in the configuration GUI

# If $true separate miners will be launched for each GPU model class, this will further help to increase profit
$DeviceSubTypes = $false

# Minimum workers required to mine on coin, if less skip the coin, there is little point in mining a coin if there are only very few miners working on it, default:7, to always mine all coins set to 0
$MinPoolWorkers = 7

# Pools and miners can charge a fee. If set to $true all profit calculations will automatically by lowered by the fee
$ProfitLessFee = $true

# WindowStyle for miner windows. Can be any of: "Normal","Maximized","Minimized","Hidden". Note: During benchmark all windows will run in "normal" mode. Warning: "Hidden" can be dangerous because the can only be seen in task manager, therefore NOT recommended
$MinerWindowStyle = "Minimized"

# If $true use alternative launcher process to run miners. The good: This will NOT steal focus. The bad: I may 'forget' to close running miners on exit. These need to be closed manually.
$UseNewMinerLauncher = $false

# Minimal required profit, if less it will not mine. The configured value must be in the first currency as defined in $currency (see config item above).
$MinProfit = 5

# Change debugging level. Can be any of "SilentlyContinue","Continue","Inquire","Stop"; see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-5.1
$DebugPreference = "SilentlyContinue"

# if $true will beep on errors
$BeepOnError=$true

# If $true will not start miners and list hypthetical earnings
$DisplayProfitOnly = $false

#i.e. BTH,ZEC,ETH etc., if supported by the pool mining earnings will be autoconverted and paid out in this currency, WARNING: make sure ALL configured pools support payout in this curreny!
$PayoutCurrency = "BTC"

# If $true will evaluate and display MPM miner is faster than... in summary, if $false MPM will not display this and instead save CPU cycles and screen space ;-)
$DisplayComparison = $false

# If $true MPM will display short pool names in summary
$UseShortPoolNames = $true

######## Power configuration (UselessGuru) ######## 
# Power configuration & true profit calculation
# Electricity price per kW, 0 will disable power cost calculation. The configured value must be in the first currency as defined in $currency (see config item above).
$PowerPricePerKW = 0.3

# Base power consumption (in Watts) of computer excluding GPUs or CPU mining.
$Computer_PowerDraw = 50

# Power consumption (in Watts) of all CPUs when mining (on top of general power ($Computer_PowerDraw) needed to run your computer when NOT mining)
$CPU_PowerDraw = 80

# Power consumption (in Watts) of all GPUs in computer when mining (in $currency[0]), put a rough estimate here.
$GPU_PowerDraw = 500
