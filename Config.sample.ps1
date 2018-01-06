# MultiPoolMiner Configuration
#
# Edit the values below and save file as "Config.ps1"
#
# Go to https://multipoolminer.io/docs for detailed information about each setting

######## USER INFORMATION ########

# Your Bitcoin payout address. Required when mining on Zpool, Hash Refinery and Nicehash.
$Wallet = "1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb"

# Your username to use to login to MiningPoolHub.
$Username = "aaronsace"

# MiningPoolHub API Key from https://miningpoolhub.com/?page=account&action=edit
$API_Key = "YOUR_MININGPOOLHUB_API_KEY"

# Choose the default currency or currencies your profit stats will be shown in.
$Currency = @("BTC","USD","EUR")

######## COMPUTER CONFIGURATION ######## 

# Worker name to show on the mining pools.  Defaults to hostname
$WorkerName = $env:COMPUTERNAME -replace '[^a-zA-Z]', ''

# [Europe/US/Asia] Choose your region or the region closest to you.
$Region = "Europe"
# [AMD,NVIDIA,CPU] Choose the relevant GPU(s) and/or CPU mining.
$Type = @("AMD","NVIDIA","CPU")

# Pools which you prefer to mine on.  All pools are always used if your preferred ones don't support the most profitable algorithm, or your preferred ones are down.
# If left empty, all pools will be treated equally, and it will mine to the most profitable pool at the moment.
# If you really want to completely disable a specific pool, delete it's file from the Pools directory.
$PoolName = @("miningpoolhub","miningpoolhubcoins","zpool","nicehash")
# Pools you prefer not to mine on. These will be used only as an absolute last resort if your preferred pools are down.
$ExcludePoolName = @()

# Algorithms to mine on this system.  If left empty, all supported algorithms will be used.
# Supported algorithms sorted by pool can be found at https://multipoolminer.io/algorithms
$Algorithm = @('cryptonight','decred','decrednicehash','ethash','ethash2gb','equihash','groestl','lbry','lyra2re2','lyra2z','neoscrypt','pascal','sia','siaclaymore','sianicehash','sib','skunk')
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
$Watchdog = $True
# Enabling SSL will restrict the miner application list to include only the miners that support secure connection.
$SSL = $False
# Specify your proxy address if applicable, i.e http://192.0.0.1:8080
$Proxy = ""
# zero does not prevent miners switching
$SwitchingPrevention = 2
# MultiPoolMiner's update interval in seconds. This is a universal timer for running the entire script (downloading/processing APIs, calculation etc). It also determines how long a benchmark is run for each miner file (miner/algorithm/coin). Default is 60.
$Interval = 60
# Specify the number of seconds required to pass before opening each miner. It is useful when cards are more sensitive to switching and need some extra time to recover (eg. clear DAG files from memory)
$Delay = 0
# Send mining status to a URL for monitoring.  This sends information about the miners running on this worker to a remote monitoring web interface
$MinerStatusURL = ""
