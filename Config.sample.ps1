# MultiPoolMiner Configuration File
#
# Edit the values below and save file as "Config.ps1"
#

######## USER INFORMATION ########

# Bitcoin wallet address used for payout in most pools
$Wallet = "1BLXARB3GbKyEg8NTY56me5VXFsX2cixFB"

# Username on miningpoolhub.com
$Username = "grantemsley"
# API Key from https://miningpoolhub.com/?page=account&action=edit
$API_Key = "YOUR_MININGPOOLHUB_API_KEY"

# Currencies to show profits and balances in.  eg. CAD, USD, ETH
$Currency = @("BTC", "CAD")

######## MINING CONFIGURATION ######## 

# Worker name to show on the mining pools.  Defaults to hostname
$WorkerName = $env:COMPUTERNAME -replace '[^a-zA-Z]', ''

# Region to mine in - europe, usa or asia
$Region = "US"
# Type(s) of mining to do - CPU, AMD, NVIDIA
$Type = @("AMD","NVIDIA","CPU")

# Pools which you prefer to mine on.  All pools are always used if your preferred ones don't support the most profitable algorithm, or your preferred ones are down.
# The order specified does not matter.
# If you really want to completely disable a specific pool, delete it's file from the Pools directory.
$PoolName = @("miningpoolhub","miningpoolhubcoins","zpool","ahashpool","hashrefinery")

# By default 24 minutes per day of mining are directed toward's the authors' addresses.  This tiny donation helps me keep improving the software.
$Donate = 24

# How often, in seconds, to update profit calculations and switch miners. Setting this lower than 60 could get you blacklisted from some APIs for hitting them too often.
$Interval = 60
# How often to wait between closing the previous miners and opening new ones.  Increase this delay if you experience crashes or failed miners when they are switching.
$Delay = 5

########### DISABLE ALGORITHM/MINER/POOL ############
$ExcludeAlgorithm = @()
$ExcludeMinerName = @()
$ExcludePoolName = @()


######## ADVANCED ######## 

$Watchdog = $True
$SSL = $False
$Proxy = ""
$Donate = 24
$SwitchingPrevention = 1 #zero does not prevent miners switching

# If $Algorithm is empty, all available algorithms are used.  Otherwise, only the ones specified will be mined.  Leave it empty to mine the most profitable options.
$Algorithm = @()

# If $MinerName is empty, all available mining programs are used.  If there are miners listed here, ONLY those ones will be used.
$MinerName = @()

