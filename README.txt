====================================================================
  __  __       _ _   _ _____            _ __  __ _                 
 |  \/  |     | | | (_)  __ \          | |  \/  (_)                
 | \  / |_   _| | |_ _| |__) |__   ___ | | \  / |_ _ __   ___ _ __ 
 | |\/| | | | | | __| |  ___/ _ \ / _ \| | |\/| | | '_ \ / _ \ '__|
 | |  | | |_| | | |_| | |  | (_) | (_) | | |  | | | | | |  __/ |   
 |_|  |_|\__,_|_|\__|_|_|   \___/ \___/|_|_|  |_|_|_| |_|\___|_|   
 
====================================================================

MultiPoolMiner - created by aaronsace, uselessguru and grantemsley 
WEBSITE: https://multipoolminer.io
GITHUB: https://github.com/MultiPoolMiner/MultiPoolMiner/releases
REDDIT: https://www.reddit.com/r/multipoolminer/
TWITTER: @multipoolminer 

Licensed under the GNU General Public License v3.0
Permissions of this strong copyleft license are conditioned on making available complete source code of licensed works and modifications, which include larger works using a licensed work, under the same license. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights. https://github.com/MultiPoolMiner/MultiPoolMiner/blob/master/LICENSE

README.txt - updated on 10/11/2019 (dd/mm/yyyy) - latest version can be found here: https://github.com/MultiPoolMiner/MultiPoolMiner/blob/master/README.txt

====================================================================


FEATURE SUMMARY:

- Monitors crypto mining pools and coins in real-time and finds the most profitable for your machine
- Controls any miner that is available via command line
- Supports benchmarking, multiple platforms (AMD, NVIDIA and CPU) and mining on A Hash Pool, BlazePool, BlockMasters, Hash Refinery, MiningPoolHub, Nicehash, YiiMP, ZergPool and Zpool pools
- Includes Watchdog Timer to detect and handle miner failures
- Comprehensive web GUI with dashboard and balances overview
- Power usage is part of the profibility calculation (optional)
- API port is configurable, default is 3999
- Invalid share detection; miner gets marked failed if the configured ration of accepted / bad shares is exceeded


Any bitcoin donations are greatly appreciated: 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH 


====================================================================


INSTALLATION:

1. Download the latest RELEASE (.zip package) from https://github.com/MultiPoolMiner/MultiPoolMiner/releases
2. Extract it to your Desktop (MultiPoolMiner will NOT work from folders such as "C:\Program Files\")
3. Make sure you have all pre-requisites installed/updated from the IMPORTANT NOTES section below.
4. Right-click on the (required) Start.bat file and open it with a Notepad application. Multiple start.bat files are included as examples.
5. Edit the Start.bat file with your details (such as YOUR username, wallet address, region, worker name, device type). New users should NOT edit anything else. Please see COMMAND LINE OPTIONS below for specification and further details.
6. Save and close the Start.bat file you just edited.
7. Launch the Start.bat file you just edited.
8. Let the benchmarking finish (you will be earning shares even during benchmarking).
9. Optional: Download, install and configure HWiNFO64, this is required if you want to make power usage a part of the profit calculation. See ConfigHWinfo64.pdf for details.

Done. You are all set to mine the most profitable coins and maximise your profits using MultiPoolMiner.


====================================================================


IMPORTANT NOTES:

- It is not recommended but to upgrade from a previous version of MultiPoolMiner, you may simply copy the 'Stats' folder.
- Having PowerShell 6.2 installed is now a requirement. Windows 64bit: https://github.com/PowerShell/PowerShell/releases/download/v6.2.1/PowerShell-6.2.1-win-x64.msi, ALL OTHER VERSIONS: https://github.com/PowerShell/PowerShell/releases
- Microsoft .NET Framework 4.5.1 or later is required for MultiPoolMiner to function properly. Please update from here: https://www.microsoft.com/en-us/download/details.aspx?id=40773
- CCMiner (NVIDIA cards only) may need 'MSVCR120.dll' if you don't already have it: https://www.microsoft.com/en-gb/download/details.aspx?id=40784. Make sure that you install both the x86 and the x64 versions. 
- CCMiner (NVIDIA cards only) may need 'VCRUNTIME140.DLL' if you don't already have it: https://www.microsoft.com/en-us/download/details.aspx?id=48145. Make sure that you install both the x86 and the x64 versions. 
- It is highly recommended to set Virtual Memory size in Windows to at least 16 GB in multi-GPU systems: Computer Properties -> Advanced System Settings -> Performance -> Advanced -> Virtual Memory
- Please see the FAQ section on the bottom of this page before submitting bugs and feature requests on Github. https://github.com/MultiPoolMiner/MultiPoolMiner/issues 
- Logs and Stats are produced in text format; use them when submitting issues.
- Currently mining with up to 6 GPUs is fully supported. Where required advanced users can create additional or amend current miner files to support mining with more than 6 graphics cards.


====================================================================
    
COMMAND LINE OPTIONS (case-insensitive - except for wallet addresses (e.g. BTC), see Sample Usage section below for an example):
Listed in alphabetical order. Note: For basic operation not all parameters must be defined through start.bat.

-AllowedBadShareRatio
	Allowed ratio of bad shares (total / bad) as reported by the miner. If the ratio exceeds the configured threshold then the miner will marked as failed. Allowed values: 0.00 - 1.00. Default of 0 disables this check

-API_Key
	Required only if you are mining at MiningPoolHub. Adding this parameter / key pair allows MPM to gather the balances at the pool. 
	The API_Key can be found in the MiningPoolHub Account detail page.

-APIPort
	Port for the MPM API and web GUI. The miner port range will start from APIPort +1. Default is 3999. 0 disables the API.

-Algorithm
	Supported algorithms sorted by pool can be found at https://multipoolminer.io/algorithms. Use commas to separate multiple values.
	The following algorithms are currently supported: 
	   Bitcore, Blakecoin, Blake2s, BlakeVanilla, C11, CryptoNightV7, CryptoNightHeavy, Ethash, X11, Decred, Equihash, Groestl, HMQ1725, HSR, JHA, Keccak, Lbry, Lyra2RE2, Lyra2z, MyriadGroestl, NeoScrypt, Pascal, Phi, Phi2, Phi1612, Polytimos, Quark, Qubit, Scrypt, SHA256, Sib, Skunk, Skein, Timetravel, Tribus, Veltor, X11, X11evo, X16R, X16S, X17, Yescrypt
	Note that the list of supported algorithms can change depending on the capabilities of the supported miner binaries. Some algos are now being mined with ASICs and are no longer profitable when mined with CPU/GPU and will get removed from MPM.

	Special parameters: 
	   Ethash2gb - can be profitable for older GPUs that have 2GB or less GDDR memory. It includes ethash coins that have a DAG file size of less than 2GB (and will be mined when most profitable). Ethereum and a few other coins have surpassed this size therefore cannot be mined with older cards.
	   ethash3gb - can be profitable for older GPUs that have 3GB or less GDDR memory. It includes ethash coins that have a DAG file size of less than 3GB (and will be mined when most profitable). Ethereum and a few other coins have surpassed this size therefore cannot be mined with older cards.
	   decrednicehash - if you want to include non-dual, non-Claymore Decred mining on Nicehash. NH created their own implementation of Decred mining protocol.
	Note that the pool selected also needs to support the required algorithm(s) or your specified pool (-poolname) will be ignored when mining certain algorithms. The -algorithm command is higher in execution hierarchy and can override pool selection. This feature comes handy when you mine on Zpool but also want to mine ethash coins (which is not supported by Zpool). WARNING! If you add all algorithms listed above, you may find your earnings spread across multiple pools regardless what pool(s) you specified with the -poolname command.

-BasePowerUsage
	Additional base power usage (in Watt) for running the computer, monitor etc. regardless of mining hardware. Allowed values: 0.0 - 999, default is 0

-BenchmarkInterval
	MultiPoolMiner's update interval in seconds during benchmarks / power metering. This is an universal timer for running the entire script (downloading/processing APIs, calculation etc). It determines how long a benchmark is run for each miner file (miner/algorithm/coin). Default is 60.
	Note: This value correlates with '-MinHashRateSamples'. If you set '-MinHashRateSamples' too high, then MPM cannot get enough samples for reliable measurement (recommendation: 10 or more). In this case increase the benchmark interval length.

-CoinName [Zcash, ZeroCoin etc.]
	Limit mining to the listed coins only; this is also a per-pool setting (see Advanced Configuration). Use commas to separate multiple values.
	Note: Only the pools ending in ...-Coin expose all coin names in their API. Check the web dashboard / pools to see which pools expose which values.

-ConfigFile [Path\ConfigFile.txt]
	The default config file name is '.\Config.txt'
	If the config file does not exist MPM will create a config file with default values. If the file name does not have an extension MPM will add .txt file name extension.
	By default MPM will use the values from the command line. If you hardcode config values directly in the config file, then these values will override the command line parameters (see Advanced Configuration).

-Currency [BTC, USD, EUR, GBP, ETH ...]
	Choose the default currency or currencies your profit stats will be shown in. Use commas to separate multiple values.
	Important: MultiPoolMiner will use the first currency in the list as main currency. All profit / earning numbers will be displayed in the main (=first in the list) currency.
	Note: Instead af BTC you can also use mBTC (= BTC / 1000).

-CurrencySymbol [BTC, LTC, ZEC etc.]
	Limit mining to the listed currency only; this is also a per-pool setting (see Advanced Configuration). Use commas to separate multiple values.
	Note: Only the pools ending in ...-Coin expose all currency symbols in their API. Check the web dashboard / pools to see which pools expose which values.

-Dashboard
	Launch web dashboard after MPM start.

-Delay
	Specify the number of seconds required to pass before opening each miner. It is useful when cards are more sensitive to switching and need some extra time to recover (eg. clear DAG files from memory)

-DeviceName
	Choose the relevant GPU(s) and/or CPU mining.  [CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.]. Use commas to separate multiple values.

-DisableDevFeeMining
	Disable miner developer fees (Note: not all miners support turning off their built in fees, others will reduce the hashrate).
	This is also a per-miner setting (see Advanced Configuration).

-DisableDeviceDetection 
	All miner by default create separate instances for each card model.
	To disable add *-DisableDeviceDetection* to your start batch file. This decreases profit.
	Note: Changing this parameter this will trigger some benchmarking.

-DisableEstimateCorrection
	Some pools overestimate the projected profits.
	By default MPM will reduce the projected algo price by a correction factor (actual_last24h / estimate_last24h) to counter the pool overestimated prices.
	Note: Not all pools include the information required for this to work in their API (currently know are MiningPoolHub & Nicehash). For these pools this setting is ignored.
	This is also a per-miner setting (see Advanced Configuration).

-DisableMinersWithDevFee
	Use only miners that do not have a dev fee built in.

-Donate
	Donation of mining time in minutes per day to aaronsace. Default is 24, minimum is 10 minutes per day (less than 0.7% fee). If Interval is set higher than the donation time, the interval will prime. The downloaded miner software can have their own donation system built in. Check the readme file of the respective miner used for more details.
	
-ExcludeAlgorithm
	Similar to the '-Algorithm' command but it is used to exclude unwanted algorithms. Supported algorithms sorted by pool can be found at https://multipoolminer.io/algorithms. Use commas to separate multiple values.
	This is also a per-pool setting (see Advanced Configuration).

-ExcludeCoinName [Zcash, ZeroCoin etc.]
	Similar to the '-CoinName' command but it is used to exclude selected coins from being mined. Use commas to separate multiple values.
	This is also a per-pool setting (see Advanced Configuration).
	Note: Only the pools ending in ...-Coin expose all coin names in their API. Check the web dashboard / pools to see which pools expose which values.

-ExcludeDeviceName
	Similar to the '-DeviceName' command but it is used to exclude unwanted devices for mining. [CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.]. Use commas to separate multiple values.

-ExcludeMinerName
	Similar to the '-MinerName' command but it is used to exclude certain miners you don't want to use. This is useful if a miner is causing issues with your machine. Use commas to separate multiple values.
	Important: Newer miners, e.g. ClaymoreEthash create several child-miner names, e.g. ClaymoreEthash-GPU#01-Pascal-40. These can also be used with '-ExcludeMinerName'.
	The parameter value(s) can be in one of the 3 forms: MinerBaseName e.g. 'TeamRed', MinerBaseName-Version, e.g. 'TeamRed-v0.5.6' or MinerName, e.g. 'TeamRed-v0.5.6-1xEllesmere8GB'. Use commas to separate multiple values.

-ExcludePoolName
	Similar to the '-PoolName' command but it is used to exclude unwanted mining pools. Use commas to separate multiple values.

-MinHashRateSamples
	Minimum number of hashrate samples MPM will collect during benchmark per interval (higher numbers produce more exact numbers, but might prolong benchmaking). Allowed values: 10 - 99 (default is 10)
    Note: This value correlates with '-BenchmarkInterval'. If MPM cannot get the minimum valid has rate samples during the configured interval, it will automatically extend the interval to up to 3x the interval length.

-HashRateSamplesPerInterval
	Approximate number of hashrate samples that MPM tries to collect per interval (higher numbers produce more exact numbers, but use more CPU cycles and memory). Allowed values: 5 - 20
	Note: This value correlates with '-Interval'. If you set '-Interval' too short, then MPM  cannot get enough samples for reliable measurement (recommendation: 10 or more). In this case increase the interval length.

-HWiNFO64_SensorMapping
	Custom HWiNFO64 sensor mapping, only required when $MeasurePowerUsage is $true, see ConfigHWinfo64.pdf
	Note: This requires advanced configuration steps (see ConfigHWinfo64.pdf)

-IgnoreFees
	Beginning with version 3.1.0 MPM makes miner and pool fees part of the profitability calculation. This will lead to somewhat lower, but more accurate profit estimates.
	Include this command to ignore miner and pool fees (as older versions did)

-IgnorePowerCost
	Include this command to ignore the power costs when calculating profit. MPM will use the miner(s) that create the highest earning regardless of the power cost, so the resulting profit may be lower.

-Interval
	MultiPoolMiner's update interval in seconds. This is an universal timer for running the entire script (downloading/processing APIs, calculation etc). It also determines how long a benchmark is run for each miner file (miner/algorithm/coin). Default is 60.
	Note: This value correlates with *-MinHashRateSamples*. If you set *-MinHashRateSamples* too short, then MPM cannot get enough samples for reliable measurement (anything over 10 is fine). In this case increase the interval length.

-IntervalMultiplier
	Interval multiplier per algorithm during benchmarking, if an algorithm is not listed the default of 1 is used.
	The default values are @{"EquihashR15053" = 2; "Mtp" = 2; "MtpNicehash" = 2; "ProgPow" = 2; "Rfv2" = 2; "X16r" = 5; "X16Rt" = 3; "X16RtGin" = 3; "X16RtVeil" = 3}
    Note: The default values can be overwritten by specifying other values in the config file (Advanced configuration via config file required, see below).

-MeasurePowerUsage
	Include this command to to gather power usage per device. This is a pre-requisite to calculate power costs and effective earnings. 
	Note: This requires advanced configuration steps (see ConfigHWinfo64.pdf)

-MinAccuracy
	Only pools with price accuracy greater than the configured value. Allowed values: 0 - 1 (default is 0.5 = 50%)
	Sometimes pools report erroneously high price spikes, just to self-correct after a few intervals. A value of 0.5 will ignore any princing information with a margin of error greater than 50%.

-MinerName
	Specify to only include (restrict to) certain miner applications.
	The parameter value(s) can be in one of the 3 forms: MinerBaseName e.g. 'TeamRed', MinerBaseName-Version, e.g. 'TeamRed-v0.5.6' or MinerName, e.g. 'TeamRed-v0.5.6-1xEllesmere8GB'. Use commas to separate multiple values.

-MinerstatusKey
	By default the MPM monitor uses the BTC address ('-Wallet') to identify your mining machine (rig). Use -MinerstatusKey [your-miner-status-key] to anonymize your rig. To get your minerstatuskey goto to https://multipoolminer.io/monitor

-MinerstatusURL https://multipoolminer.io/monitor/miner.php
	Report and monitor your mining rig's status by including the command above. Wallet address must be set even if you are only using MiningPoolHub as a pool. You can access the reported information by entering your wallet address on the https://multipoolminer.io/monitor web address. By using this service you understand and accept the terms and conditions detailed in this document (further below). 

-MinWorker
	Minimum numner of workers at the pool required to mine on algo / coin, if less skip the algo / coin, there is little point in mining an algo or coin if there are only very few miners working on it, default: {"*": = 10}, to always mine all coins set to 0.
	Wildcards (* and ?) for the algorithm names are supported. If an algorithm name/wildcard matches more than one entry then the lower number takes priority.
	this is also a per-pool setting (see Advanced Configuration).

-PoolBalancesUpdateInterval
	MPM queries the pool balances every n minutes. Default is 15, minimum is 0 (=on every loop). MPM does this to minimize the requests sent to the pools. Pools usually do not update the balances in real time, so querying on each loop is unnecessary.
	Note: The balance overview is still shown on each loop.
    
-Poolname [ahashpool[-algo / -coin], blazepool[-algo / -coin], blockmasters[-algo / -coin], hashrefinery[-algo / -coin], miningpoolhub[-algo / -coin], nicehash(old), nlpool[-algo / -coin], phiphipool (deprecated), ravenminer, zergpool[-algo / -coin], zpool[-algo / -coin]]
	The following pools are currently supported (in alphabetical order); use commas to separate multiple values:

    ## AHashPool-Algo / AHashPool-Coin
      WebSite: https://www.ahashpool.com/ 
      Payout in BTC (Bitcoin address must be provided using the '-Wallet' command)
      AHashPool-Coin allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via config. file required, see below).

    ## BlazePool-Algo / BlazePool-Coin
      WebSite: http://www.blazepool.com/ 
      Payout in BTC (Bitcoin address must be provided using the '-Wallet' command)
      BlazePool-Coin allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via config. file required, see below).

    ## BlockMasters-Algo / BlockMasters-Coin
      WebSite: http://www.blockmasters.co/
      Payout in BTC (Bitcoin address must be provided using the '-Wallet' command), or any currency available in API (Advanced configuration via config file required, see below).
      BlockMasters-Coin allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via config. file required, see below).

    ## HashRefinery-Algo / HashRefinery-Coin
      WebSite: http://pool.hashrefinery.com
      Payout in BTC (Bitcoin address must be provided using the '-Wallet' command)
      HashRefinery-Coin allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via config. file required, see below).

    ## MiningPoolHub-Algo / MiningPooHub-Coin
      WebSite: https://miningpoolhub.com/ 
      - 'miningpoolhub-algo' parameter uses the 17xxx ports therefore allows the pool to decide on which coin is mined of a specific algorithm
      - 'miningpoolhub-coin' allows for MultiPoolMiner to calculate and determine what is mined from all of the available coins (20xxx ports). 
      Usage of the 'miningpoolhub' parameter is recommended as the pool have internal rules against switching before a block is found therefore prevents its users losing shares submitted due to early switching. A registered account is required when mining on MiningPoolHub (username must be provided using the -username command, see below).
      Payout in BTC (Bitcoin address must be provided using the -wallet command, see below), or any currency available in API (Advanced configuration via config file required, see below).
      MiningPooHub-Coin allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via config file required, see below).

    ## Nicehash(old) 
      WebSite: https://www.nicehash.com / https://old.nicehash.com
      Payout in BTC (Bitcoin address must be provided using the *-Wallet* command) or BCH, ETX, LTC, XRP or AND ZEC (currency must be provided in config file (Advanced configuration via config file required, see below).

    ## NLPool
      WebSite: https://www.nlpool.nl/
      Payout in BTC (Bitcoin address must be provided using the -wallet command, see below), LTC or any currency available in API (Advanced configuration via config file required, see below).

    ## PhiPhiPool (Deprecated)
      WebSite: https://www.phi-phi-pool.com
      Note: PhiPhiPool no longer offers auto-conversion to BTC. Do NOT mine with a BTC address.
      A separate wallet address for each mined currency must be provided in config file (Advanced configuration via config file required, see below).

    ## Ravenminer 
      WebSite: https://ravenminer.com
      Payout in RVN. A separate RVN wallet address must be provided in config file (Advanced configuration via config file required, see below).

    ##ZergPool-Algo / ZergPool-Coin
      WebSite: http://zergpool.eu
      Payout in BTC (Bitcoin address must be provided using the *-Wallet* command), or any currency available in API (Advanced configuration via config file required, see below).
       ZergPool-Coin allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via config file required, see below).

    ##Zpool-Algo / Zpool-Coin
      WebSite: http://www.zpool.ca/
      Payout in BTC (Bitcoin address must be provided using the '-Wallet' command), or any currency available in API (Advanced configuration via config file required, see below).
      Zpool-Coin allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via config file required, see below)

      IMPORTANT: For the list of default configured pools consult 'start.bat.' This does not rule out other pools to be included. Selecting multiple pools is allowed and will be used on a failover basis OR if first specified pool does not support that algorithm/coin. See the '-Algorithm' command for further details and example.*

-PowerPrices
	Power price per kW·h, set value for each time frame, e.g. {"00:00"=0.3;"06:30"=0.6;"18:30"=0.3}, 24hr format!

-PricePenaltyFactor
	Default factor with which MPM multiplies the prices reported by ALL pools. The default value is 1 (valid range is from 0.1 to 1.0). 
	E.g. If you feel that the general profit estimations as reported by MPM are too high, e.g. %20, then set '-PricePenaltyFactor' to 0.8. 
	This is also settable per pool (see advanced configuration below). The value set on the pool level will override this general setting.

-ProfitabilityThreshold = 0
	Minimum profit (in $Currency[0]) that must be made otherwise all mining will stop, set to 0 to allow mining even when making losses. Allowed values: 0.0 - 999, default is 0

-Proxy
	Specify your proxy address if applicable, i.e http://192.0.0.1:8080

-Region [Europe/US/Asia]
	Choose your region or the region closest to you.

-ReportStatusInterval
    Seconds until next miner status update (https://multipoolminer.io/monitor). Allowed values 30 - 300. Set to 0 to disable status reporting.

-ShowAllMiners (replaces '-UseFastestMinerPerAlgoOnly' as used in versions before 3.3.0)
	Include this command to list all available miners per algo and device index in the summary screen.
	By default, if there are several miners available to mine the same algo, only the most profitable of them will be listed in the summary screen. 
	Note: In benchmark mode ALL available miners wil be listed

-ShowAllPoolBalances
	Include this command to display the balances of all pools (including those that are excluded with '-ExcludeMinerName') on the summary screen and in the web GUI. 

-ShowMinerWindow
	Include this command to show the running miner windows (minimized).
	By default MPM hides most miner windows as to not steal focus (Miners of API type 'Wrapper' will remain hidden). Hidden miners write their output to files in the Log folder.

-ShowPowerUsage
	Include this command to show power usage in miner overview list
	Note: This requires advanced configuration steps (see ConfigHWinfo64.pdf)
 
-SingleAlgoMining
	To prevent dual algorithm mining, add '-SingleAlgoMining' to your start batch file.

-SSL
	Specifying the '-SSL' command (without a boolean value of true or false) will restrict the miner application list to include only the miners that support secure connection.

-SwitchingPrevention
	Since version 2.6, the delta value (integer) that was used to determine how often MultiPoolMiner is allowed to switch, is now user-configurable on a scale of 1 to infinity on an intensity basis. Default is 1 (Start.bat default is 2). Recommended values are 1-10 where 1 means the most frequent switching and 10 means the least switching. Please note setting this value to zero (0) will not turn this function off! Please see further explanation in MULTIPOOLMINER'S LOGIC section below. 

-UserName 
	Your username you use to login to MiningPoolHub.

-Wallet
	Your Bitcoin payout address. Required when mining on AhashPool, BlazePool, Hash Refinery, Nicehash and Zpool (unless you have defined another payout currency (Advanced configuration via config file required, see below).

-WarmupTime
	Time a miner is allowed to warm up before it could get marked as failed, e.g. to compile the binaries or to get the API ready. Default is 30 (seconds).
	
-Watchdog
	Include this command to enable the watchdog feature which detects and handles miner and other related failures.
	It works on a unified interval that is defaulted to 60 seconds. Watchdog timers expire if three of those intervals pass without being kicked. There are three stages as to what action is taken when watchdog timers expire and is determined by the number of related expired timers.
	- Stage 1: when 1 timer expires relating to one miner/algorithm combination, the one miner/algorithm combination is kicked
	- Stage 2: when 2 timers expire relating to one miner file, the one miner file is kicked
	- Stage 3: when 3 timers expire relating to one pool, the pool is kicked
	Watchdog timers reset after three times the number of seconds it takes to get to stage 3.

-WorkerName
	To identify your mining rig.	



SAMPLE USAGE (check "start.bat" file in root folder):

############ START OF CONTENT OF START.BAT ############
@echo off
cd /d %~dp0

rem ON MINING RIGS SET MININGRIG=TRUE
SET MININGRIG=FALSE

if not "%GPU_FORCE_64BIT_PTR%"=="1" (setx GPU_FORCE_64BIT_PTR 1) > nul
if not "%GPU_MAX_HEAP_SIZE%"=="100" (setx GPU_MAX_HEAP_SIZE 100) > nul
if not "%GPU_USE_SYNC_OBJECTS%"=="1" (setx GPU_USE_SYNC_OBJECTS 1) > nul
if not "%GPU_MAX_ALLOC_PERCENT%"=="100" (setx GPU_MAX_ALLOC_PERCENT 100) > nul
if not "%GPU_SINGLE_ALLOC_PERCENT%"=="100" (setx GPU_SINGLE_ALLOC_PERCENT 100) > nul
if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

set "command=& .\multipoolminer.ps1 -Wallet 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb -UserName aaronsace -WorkerName multipoolminer -Region europe -Currency btc,usd,eur -DeviceName amd,nvidia,cpu -PoolName miningpoolhubcoins,zpool,nicehash -Algorithm blake2s,cuckaroo39,cuckatoo31,cryptonightR,cryptonightV8,cryptonightheavy,decrednicehash,ethash,ethash2gb,ethash3gb,equihash,equihash1445,equihash1505,keccak,lbry,lyra2re3,mtp,mtpnicehash,neoscrypt,pascal,sib,skein,skunk,sonoa,timetravel10,x16r,x16rt,x16s,x17,x22i -Donate 24 -Watchdog -MinerStatusURL https://multipoolminer.io/monitor/miner.php -SwitchingPrevention 2"

if exist "~*.dll" del "~*.dll" > nul 2>&1

if /I "%MININGRIG%" EQU "TRUE" goto MINING

rem Launch web dashboard
set "command=%command% -Dashboard"

if exist ".\SnakeTail.exe" goto SNAKETAIL

start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log 'MultiPoolMiner_\d\d\d\d-\d\d-\d\d\.txt' -sort '^[^_]*_' -quickstart"
goto MINING

:SNAKETAIL
tasklist /fi "WINDOWTITLE eq SnakeTail - MPM_SnakeTail_LogReader*" /fo TABLE 2>nul | find /I /N "SnakeTail.exe" > nul 2>&1
if "%ERRORLEVEL%"=="1" start /min .\SnakeTail.exe .\MPM_SnakeTail_LogReader.xml

:MINING
pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

echo Powershell 6 or later is required. Cannot continue.
pause

############ END OF CONTENT OF START.BAT ############


====================================================================


ADVANCED CONFIGURATION

Advanced config options are available via config file

MPM supports customized configuration via config files. The default config file name is '.\Config.txt'.
If you do not include the command line parameter -ConfigFile [Path\FileName.txt] then MPM will use the default file name. 

If the config file does not exist MPM will create a config file with default values. If the file name does not have an extension MPM will add .txt file name extension.
The default config file contains only the parameters which are also available per command line. 
Note: More config items are added to the live configuration during runtime. For full list of available config items at runtime see the API at http://localhost:3999/config. All items could also be added manually to the config file (use with caution as this might lead to unpredictable results).

The config file is a JSON file and human readable / editable. A good primer for understanding the JSON structure can be found here: https://www.tutorialspoint.com/json/index.htm

Warning: The JSON file structure is very fragile - every comma counts, so be careful when editing this file manually. To test the validity of the structure use a web service like https://jsonblob.com (copy/paste the complete file).

Sample content of 'Config.txt'

{
  "Algorithm": "$Algorithm",
  "AllowedBadShareRatio": "$AllowedBadShareRatio",
  "API_ID": "$API_ID",
  "API_Key": "$API_Key",
  "APIPort": "$APIPort",
  "BasePowerUsage": "$BasePowerUsage",
  "BenchmarkInterval": "$BenchmarkInterval",
  "CoinName": "$CoinName",
  "ConfigFile": "$ConfigFile",
  "Currency": "$Currency",
  "CurrencySymbol": "$CurrencySymbol",
  "Dashboard": "$Dashboard",
  "Debug": "$Debug",
  "Delay": "$Delay",
  "DeviceName": "$DeviceName",
  "DisableDevFeeMining": "$DisableDevFeeMining",
  "DisableDeviceDetection": "$DisableDeviceDetection",
  "DisableEstimateCorrection": "$DisableEstimateCorrection",
  "DisableMinersWithDevFee": "$DisableMinersWithDevFee",
  "Donate": "$Donate",
  "ErrorAction": "$ErrorAction",
  "ErrorVariable": "$ErrorVariable",
  "ExcludeAlgorithm": "$ExcludeAlgorithm",
  "ExcludeCurrencySymbol": "$ExcludeCurrencySymbol",
  "ExcludeCoinName": "$ExcludeCoinName",
  "ExcludeDeviceName": "$ExcludeDeviceName",
  "ExcludeMinerName": "$ExcludeMinerName",
  "ExcludePoolName": "$ExcludePoolName",
  "HashRateSamplesPerInterval": "$HashRateSamplesPerInterval",
  "HWiNFO64_SensorMapping": "$HWiNFO64_SensorMapping",
  "IgnoreFees": "$IgnoreFees",
  "IgnorePowerCost": "$IgnorePowerCost",
  "InformationAction": "$InformationAction",
  "InformationVariable": "$InformationVariable",
  "Interval": "$Interval",
  "IntervalMultiplier": "$IntervalMultiplier",
  "MeasurePowerUsage": "$MeasurePowerUsage",
  "MinAccuracy": 0.5,
  "MinerName": "$MinerName",
  "MinerStatusKey": "$MinerStatusKey",
  "MinerStatusUrl": "$MinerStatusUrl",
  "MinHashRateSamples": "$MinHashRateSamples",
  "Currency": "$Currency",
  "MinWorker": "$MinWorker",
  "OutBuffer": "$OutBuffer",
  "OutVariable": "$OutVariable",
  "PipelineVariable": "$PipelineVariable",
  "PoolBalancesUpdateInterval": "$PoolBalancesUpdateInterval",
  "PoolName": "$PoolName",
  "PowerPrices": "$PowerPrices",
  "PricePenaltyFactor": "$PricePenaltyFactor",
  "ProfitabilityThreshold": "$ProfitabilityThreshold",
  "Proxy": "$Proxy",
  "Region": "$Region",
  "ReportStatusInterval": "$ReportStatusInterval",
  "ShowAllMiners": "$ShowAllMiners",
  "ShowAllPoolBalances": "$ShowAllPoolBalances",
  "ShowMinerWindow": "$ShowMinerWindow",
  "ShowPowerUsage": "$ShowPowerUsage",
  "SingleAlgoMining": "$SingleAlgoMining",
  "SSL": "$SSL",
  "SwitchingPrevention": "$SwitchingPrevention",
  "UserName": "$UserName",
  "Verbose": "$Verbose",
  "Wallet": "$Wallet",
  "WarmupTime": "$WarmupTime",
  "WarningAction": "$WarningAction",
  "WarningVariable": "$WarningVariable",
  "Watchdog": "$Watchdog",
  "WorkerName": "$WorkerName",
  "Pools": {},
  "MinersLegacy": {},
  "Wallets": {
    "BTC": "$Wallet"
  },
  "VersionCompatibility": "3.3.0"
}

There is a section for Pools, Miners and a general section

Advanced configuration for Pools

Settings for each configured pool are stored in its own subsection. These settings are only valid for the named pool.


CoinName per pool [Zcash, ZeroCoin etc.]

Only mine the selected coins at the specified pool.

E.g. To mine only Zcash & ZeroCoin at Zpool:

    "Zpool-Coin": {
      "CoinName":  [
        "Zcash",
        "ZeroCoin"
      ]
    }
Note: Only the pools ending in ...-Coin expose the coin name in their API.


CurrencySymbol per pool [DGB, LTC, ZEC etc.]

Only mine the selected currencies at the specified pool.

E.g. To mine only LTC & ZEC at Zpool:

    "Zpool-Coin": {
      "CurrencySymbol":  [
        "LTC",
        "ZEC"
      ]
    }
Note: Only the pools ending in ...-Coin expose all currency symbols in their API. Check the web dashboard / pools to see which pools expose which values.


DisableEstimateCorrection per pool

Some pools overestimate the projected profits. By default MPM will reduce the projected algo price by a correction factor (actual_last24h / estimate_last24h) to counter pool the overestimated prices.
E.g. To disable this at Zpool:

    "Zpool-Algo": {
      "DisableEstimateCorrection":  false
    }


ExcludeAlgorithm per pool

Do not use the configured algorithms for mining at the specified pool.

E.g. To NOT mine Equihash and Ethash2gb at Zpool:

    "Zpool-Coin": {
      "ExcludeAlgorithm":  [
        "Equihash",
        "Ethash2gb"
      ]
    }


ExcludeCoinName per pool [Zcash, ZeroCoin etc.]

Exclude selected coins from being mined at the specified pool.

E.g. To NOT mine Zcash & ZeroCoin at Zpool:

    "Zpool-Coin": {
      "ExcludeCoinName":  [
        "Zcash",
        "ZeroCoin"
      ]
    }
Note: Only the pools ending in ...-Coin expose the coin name in their API.


ExcludeCurrencySymbol per pool [DGB, LTC, ZEC etc.]

Exclude selected currency symbol from being mined at the specified pool.

E.g. To NOT mine DGB & LTC at Zpool:

    "Zpool-Coin": {
      "ExcludeCurrencySymbol":  [
        "DGB",
        "LTC"
      ]
    }
Note: Only the pools ending in ...-Coin expose all currency symbols in their API. Check the web dashboard / pools to see which pools expose which values.


ExcludeRegion per pool

Do not use the pool endpoints in select regions. This may be useful when a pool has a problem with its endpoints in some regions, e.g. https://bitcointalk.org/index.php?topic=472510.msg51637436#msg51637436.

E.g. To NOT use the MiningPoolHub mining endpoints in region 'Europe':

    "MiningPoolHub-Algo": {
      "ExcludeRegion":  [
        "Europe"
      ]
    }
Note: The values for 'Regions' must match the definitions in 'Regions.txt'.


MinWorker

This parameter allows to define a required minimum number of workers at the pool per algorithm. If there are less then the configured number of workers MPM will skip the affected algorithms.
Wildcards (* and ?) for the algorithm names are supported. If an algorithm name/wildcard matches more than one entry then the lower number takes priority.
Important: The general '-MinWorker' value is always applied. Only algorithms matching the global workers count will eventually be handled by the per-pool config. 

E.g. To ignore 'Ethash*' & 'Equihash1445' algorithms at MiningPoolHub if there are less than 10 workers set MinWorker like this:

    "MiningPoolHub-Algo": {
      "MinWorker":  {
        "Ethash*":  10,
        "Equihash1445":  10
      }
    }
Note: Not all pools support this, for more information consult the pools web page or check the MPM web GUI
If *-MinWorker* is set on a general AND pool level, then the lower number takes priority.


NiceHash internal wallet

If you have a NiceHash internal wallet you can configure MPM/NiceHash Pool to mine to the internal address. MPM will then use the lower pool fee of 1% for calculations.
To use the NiceHash internal wallet modify the NiceHash pool section (you may have to create is first). Enter your "<YOUR_NICEHASH_INTERNAL_WALLET>" (of course you need to insert the real BTC address), and set the flag '"IsInternalWallet":  true':

    "NiceHash":  {
      "Wallets":  {
        "BTC":  "<YOUR_NICEHASH_INTERNAL_WALLET>"
      },
      "IsInternalWallet":  true
    }


Payout currency

If a pool allows payout in another currency than BTC you can set the currency you wish to be paid.
By default MPM will add ALL currencies configured by $Wallet as possible payout currencies for the pool.

For each pool you can statically add a section similar to this to your config file:
    "Zpool-Algo": {
      "Wallets":  {
        "BTC": "$Wallet"
      },
      "Worker": "$WorkerName"
    }

The payout currency is defined by this line:
"BTC": "$Wallet", (MPM will use the the wallet address from the start.bat file)

E.g. to change the payout currency for Zpool to LiteCoin replace the line for BTC with "LTC": "<YOUR_LITECOIN_ADDRESS>", (of course you need to insert a real LTC address)

    "Zpool-Algo": {
      "Wallets":  {
        "LTC": "<YOUR_LITECOIN_ADDRESS>"
      },
      "Worker": "$WorkerName"
    }
Note: Not all pools support this, for more information consult the pools web page


PricePenaltyFactor per pool

If you feel that a pool is exaggerating its estimations then set a penalty factor to lower projected projected calculations.
E.g. You feel that Zpool is exaggerating its estimations by 10% - Set PricePenaltyFactor to 0.9:

    "Zpool-Algo": {
      "PricePenaltyFactor":  0.9
    }
Note: This is also a general parameter (see -PricePenaltyFactor). If both parameters - general and pool - are present, then the pool parameter takes precedence.


Regions per pool

Only use pool endpoints is selected regions. This may be useful when a pool has a problem with its endpoints in some regions, e.g. https://bitcointalk.org/index.php?topic=472510.msg51637436#msg51637436.

E.g. To use MiningPoolHub mining endpoints in regions 'Asia' and 'US' ONLY:

    "MiningPoolHub-Algo": {
      "Region":  [
        "Asia",
        "US"
      ]
    }
Note: The values for 'Regions' must match the definitions in 'Regions.txt'.


Blockmasters &  ZergPool(Coins) Solo/Party mining

Check the pools web page for more information first!
For Blockmasters & ZergPool(Coins) solo or party mining edit the config file like this:   

    "Pools": {
      "Blockmasters-Algo": {
        "PasswordSuffix": {
          "Algorithm": {
            "*": "",
            "Equihash": ",m=solo"
          }
        }
      },
      "ZergPool-Coin": {
        "PasswordSuffix": {
          "Algorithm": {
            "*": "",
            "Equihash": ",m=solo"
          },
          "CoinName": {
            "*": "",
            "Digibyte": ",m=solo"
          }
        }
      }
    }

"*" stands for any algorithm / coinname. No other wildcards are allowed.
All values are cumulative, so if you specify a value for algorithm AND coinname, then both values will be appended.


Advanced configuration for Miners

Settings for each configured miner are stored in its own subsection. These settings are only valid for the named miner.


ExcludeAlgorithm per miner

E.g. To exclude the Ethash3gb algorithm from any version of the ClaymoreEthash miner:

    "MinersLegacy": {
      "ClaymoreEthash": {
        "*": {
          "ExcludeAlgorithm": [
            "Ethash2gb"
          ]
        }
      }
    }

E.g. To exclude the Ethash2gb or Blake2s algorithms from ClaymoreEthash-v15.0 miner:

    "MinersLegacy": {
      "ClaymoreEthash": {
        "v15.0": {
          "ExcludeAlgorithm": [
            "Blake2s",
            "Ethash2gb"
          ]
        }
      }
    }
"*" stands for ANY miner version.
The algorithm name must be entered in the normalized form as returned by Get-Algorithm.
If both, a version specific and generic config ("*") exist, then all matching algorithms are excluded.


Disable miner developer fee per miner

Note: not all miners support turning off their built in fees, others will reduce the hashrate, check the miners web page for more information

E.g. To disable the dev fee mining from any version of the ClaymoreEthash miner:

    "MinersLegacy": {
      "ClaymoreEthash": {
        "*": {
          "DisableDevFeeMining":  true
        }
      }
    }

E.g. To disable the dev fee mining from ClaymoreEthash-v15.0 miner:

    "MinersLegacy": {
      "ClaymoreEthash": {
        "v15.0": {
          "DisableDevFeeMining":  true
        }
      }
    }
"*" stands for ANY miner version.
If this setting is defined in multiple places (version specific, version generic ("*") and global), then the most specific value is used.


Secondary algorithm intensities (dual algo miners only)

The mining intensities for secondary algorithms can be configured in the config file.

The miner name must be entered without the ending version number (e.g. for ClaymoreEthash-v15.0 remove -v15.0)
The algorithm names must be entered as the miner uses it, do not use the normalized algorithm name as returned by Get-Algorithm.

    "MinersLegacy": {
      "ClaymoreEthash": {
        "*": {
          "SecondaryAlgoIntensities": {
            "blake2s": [
              45,
              60,
              75
            ],
            "pascal": [
              30,
              60,
              90
            ]
          }
        },
        "v15.0": {
          "SecondaryAlgoIntensities": {
            "decred": [
              25,
              40,
              65
            ]
          }
        }
      }
    }
"*" stands for ANY version
If both, specific (e.g. miner version) and generic config ("*") exist, then only the specific config is used. The generic config will be ignored entirely.
If you do not specify clustom values for all algorithms, then the miners default values will be applied for the unconfigured algorithms.


Customize miner commands

MPM stores all default miner commands (= what algos to mine and the commands to do so) in the miner file. You can override these commands with your own by modifing the config file.

The miner name must be entered without the ending version number (e.g. for ClaymoreEthash-v15.0 remove -v15.0)
The algorithm name must be entered in the normalized form as returned by Get-Algorithm.
Commands must match the data structure as found in the existing miner files. Note: Not all miners use the same parameters.

    "MinersLegacy": {
      "ClaymoreEthash": {
        "*": {
          "AllCommands": [
            {
              "MainAlgorithm": "Ethash2gb",
              "MinMemGB": 2,
              "SecondaryAlgorithm": "blake2s",
              "SecondaryIntensity": 25,
              "Params": " -colors"
            },
            {
              "MainAlgorithm": "ethash3gb",
              "MinMemGB": 2,
              "SecondaryAlgorithm": "blake2s",
              "SecondaryIntensity": 35,
              "Params": " -colors"
            }
          ],
          "CommonCommands": " -dbg -1"
        },
        "v15.0": {
          "AllCommands": [
            {
              "MainAlgorithm": "Ethash2gb",
              "MinMemGB": 2,
              "SecondaryAlgorithm": "blake2s",
              "SecondaryIntensity": 25,
              "Params": " -colors"
            },
            {
              "MainAlgorithm": "ethash3gb",
              "MinMemGB": 2,
              "SecondaryAlgorithm": "blake2s",
              "SecondaryIntensity": 35,
              "Params": " -colors"
            }
          ],
          "CommonCommands": " -dbg -1"
        }
      }
    }
"*" stands for ANY version or ANY algorithm.
If both, specific (e.g. miner version / algorithm name) and generic config ("*") exist, then only the specific config is used. The generic config will be ignored entirely.

Commands: These settings will be added to the miner command line for the selected miner algorithm.
CommonCommands: These settings will be added to the miner command line for ALL miner algorithms.
Commands and CommonCommands are cumulative.


Pre- / post miner program execution

MPM can execute any program/script/batch file on any of these events:

- before a miner gets started (PreStopCommand)
- after a miner got startet (PostStartCommand)
- before a miner gets started (PreStopCommand)
- after a miner got stopped (PostStopCommand)
- after miner failure got detected (PostFailureCommand)

Modify the config file to define the program and its parameters. E.g.

    "MinersLegacy": {
      "*": {
        "PreStartCommand": "_ the command put here would be run before ANY miner gets started",
        "PostStartCommand": "cmd.exe /c ECHO $((Get-Date).ToUniversalTime()): Starting miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {\"$($_)@$($Pools.$_.Name)\"}) -join \"; \")}).  >> .\\Logs\\minerstart.log",
        "PreStopCommand": "REM run this command before the miner gets stopped",
        "PostStopCommand": "cmd.exe /c ECHO $((Get-Date).ToUniversalTime()): Stopped miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {\"$($_)@$($Pools.$_.Name)\"}) -join \"; \")}).  >> .\\Logs\\minerstop.log",
        "PostFailureCommand": "_ the command put here would be run after any miner failure"
      },
      "lolMinerEquihash": {
        "*": {
          "PreStartCommand": "'C:\\Program Files (x86)\\MSI Afterburner\\MSIAfterburner.exe' -Profile1",
          "PostStartCommand": ""
          "PreStopCommand": "_ the command put here would be run  before lolMinerEquihash miner (any version) gets stopped",
          "PostStopCommand": "",
          "PostFailureCommand": ""
        }
      },
      "CryptoDredge": {
        "v0.22.0": {
          "PreStartCommand": "'C:\\Program Files (x86)\\MSI Afterburner\\MSIAfterburner.exe' -Profile2",
          "PostStartCommand": ""
          "PreStopCommand": "_ the command put here would be run before CryptoDredge-v0.20.2 miner gets stopped",
          "PostStopCommand": "",
          "PostFailureCommand": "shutdown /r /t 10"
        }
      }
    }
"*" stands for ANY miner or ANY miner version.
The miner name must be entered without the ending version number (e.g. for NVIDIA-CryptoDredge-v0.20.2 remove -v0.20.2)
Important: If two or more entries match, then the more specific entry is executed.

Double quotes (") or backslashes must be escaped with backslash as shown below.
To execute simple batch file commands you need to use 'cmd.exe /c '.
You can also use any MPM internal variables or simple powershell code like this:
      "PreStartCommand": "$(if (($Miner.Algorithm | Select-Object -Index 0) -eq \"MTP") {\"'C:\\Program Files\\Tools\\MSI Afterburner\\MSIAfterburner.exe' -Profile1\"})",
      "PostStartCommand": "cmd.exe /c ECHO $((Get-Date).ToUniversalTime()): Started miner ($($Miner.Name) {$(($Miner.Algorithm | ForEach-Object {\"$($_)@$($Pools.$_.Name)\"}) -join \"; \")}).  >> .\\Logs\\minerstart.log"


Advanced general configuration

Settings in this section affect the overall behaviour of MPM and will take precedence over command line parameters.

Ignore pool and miner fees

Beginning with version 3.1.0 MPM makes miner and pool fees part of the profitability calculation. This will lead to somewhat lower, but more accurate profit estimates.

To ignore miner and pool fees (as older versions did) add '"IgnoreFees":  true' to the general section:

    {
      "SwitchingPrevention":  "$SwitchingPrevention",
      "IgnoreFees":  true
    }


Interval Multiplier

Some algorithms produce very fluctuating hash rate numbers. In oder to get more stable values these algorithms require a longer benchmark period.
To override the defaults add a section similar to this to the general section in the config file (these are the default values):

    "IntervalMultiplier": {
        "EquihashR15053": 2,
        "Mtp": 2,
        "MtpNicehash": 2,
        "ProgPow": 2,
        "Rfv2": 2,
        "X16r": 5,
        "X16Rt": 3,
        "X16RtGin": 3,
        "X16RtVeil": 3
    }   
Note: The custom config section in the config file replaces the defaults for ALL algorithms. Any algorithm not explicitly configured will be set to the default value of 1 (unless there is a hardcoded value in the miner file).


PricePenaltyFactor

Default factor with which MPM multiplies the prices reported by ALL pools. The default value is 1 (valid range is from 0.1 to 1.0). 
E.g. You feel that MPM is exaggerating its profit estimations by 20% for ALL pools - Set PricePenaltyFactor to 0.8:

    {
      "SwitchingPrevention":  "$SwitchingPrevention",
      "PricePenaltyFactor":  0.8
    }
Note: This is also a pool parameter (see PricePenaltyFactor per pool). If both parameters - general and pool - are present, then the pool parameter takes precedence.

To show miner windows

By default MPM hides most miner windows as to not steal focus . All miners write their output to files in the Log folder.

To show the miner windows add '"ShowMinerWindow":  true' to the general section:

    {
      "SwitchingPrevention":  "$SwitchingPrevention",
      "ShowMinerWindow":  true
    }
Note: Showing the miner windows disables writing the miner output to log files. Miners of API type 'Wrapper' will remain hidden.


Pool Balances

MPM can gather the pending BTC balances from all configured pools.

To display the balances of all enabled pools (excluding those that are excluded with '-ExcludeMinerName') on the summary screen and in the web GUI add '"ShowPoolBalances":  true' to the general section:
    {
      "SwitchingPrevention":  "$SwitchingPrevention",
      "ShowPoolBalances":  true
    }

To display the sum of each currency in the balances (depending on 'ShowPoolBalancesExcludedPools' including those that are excluded with 'ExcludeMinerName') and the exchange rates for all currencies on the summary screen add '"ShowPoolBalancesDetails": true' to the general section:
    {
      "SwitchingPrevention":  "$SwitchingPrevention",
      "ShowPoolBalancesDetails": true
    }	

To display the balances of all pools (including those that are excluded with '-ExcludeMinerName') on the summary screen and in the web GUI add '"ShowPoolBalances":  true' to the general section:
    {
      "SwitchingPrevention":  "$SwitchingPrevention",
      "ShowPoolBalancesExcludedPools":  true
    }
Note: Only balances in BTC are listed, other currencies are currently not supported.


UNPROFITABLE ALGORITHMS

As more and more algorithms can be mined with ASICs mining them with GPUs becomes unprofitable.
To add algorithms to the list edit 'UnprofitableAlgorithms.txt' in the MPM directory.

[
     "Bitcoin",
     "Blake2s",
     "BlakeCoin",
     "BlakeVanilla",
     "Cryptolight",
     "Cryptonight",
     "CryptonightV7",
     "Decred",
     "Groestl",
     "Keccak",
     "KeccakC",
     "Lbry",
     "Lyra2RE",
     "Lyra2RE2",
     "Lyra2z",
     "MyriadGroestl",
     "Nist5",
     "Quark",
     "Qubit",
     "Scrypt",
     "ScryptN",
     "SHA256d",
     "SHA256t",
     "Sia",
     "Sib",
     "Skein",
     "X11",
     "X13",
     "X14",
     "X15"
 ]

Note: MPM will no longer mine/benchmark these algorithms as main algorithms, but they will still be used as secondary algorithm for dual miners.



====================================================================

MULTIPOOLMINER'S LOGIC:

General overview:

    - The various pools estimated profit values (visible on their respective web pages) are determined by the pools themselves. Each algorithm's estimated profit value is a combination of the current mined coin's last known exchange value in BTC, the coins network difficulty (or network hashrate) and the current pools overall hashrate.
    - MPM polls all pools it knows about (enabled or not) on a pre-defined interval (default is every 60 seconds) to gather the pools estimated profit for all of its advertised algorithms. As these profits change at each polling interval (based on the three factors mentioned above), MPM tracks how often and how drastic the changes are per algorithm and records this per-algorithm as a "fluctuation" metric. This fluctuation or margin-of-error is represented in MPM's output as "accuracy". e.g. An algorithm whose reported estimated profit values have a 90% accuracy can be conversely thought of as having a 10% margin-of-error.
    - As MPM repeatedly polls the pools over time, the more correct the reported accuracy (i.e. margin of error) becomes for a particular pools algorithm.
    Due to the nature of pool-based mining, it is generally considered better to mine longer on algorithms that are most profitable with low margin-of-error over time (i.e. high accuracy). Technically, this takes into account concepts like PPLNS vs. PPS, ramp-up time for reported pool hash rate vs. miner reported hash rates, new/cheap coins with wildly fluctuating exchange prices etc.

Switching (or anti-switching) logic:

    - MPM retrieves the estimated profit for all pools/algorithms and filters out any undesired algorithms.
    - The estimated profit for each pool/algorithm combo is reduced by a calculated percentage amount (see below for specifics) to determine a "biased" estimated profit.
    - The "biased" estimated profits for each enabled pool/algorithm are combined with the benchmark hashrates previously calculated for all miners to calculate potential profit for your specific rig.
    - The most profitable miner/algorithm/pool combination for your rig is selected and (if it isn't already running) it is launched.
    - MPM idles for a pre-defined interval of time (default 60 seconds), then repeats the steps above.

Formula:
	[Price] x (1 - ([Fluctuation] x [Switching Prevention] x 0.9^[Intervals Past]))
	i.e. 123 x (1 - (0.2 x 2 x 0.9^5)
	where:
	123 is BTC
	1 is 100%
	0.2 is 80% accuracy
	0.9 is 10% reduction
	5 is minutes if interval is 60 seconds

Example 1:
	If SwitchingPrevention = 2 and accuracy of most profitable coin = 90%
	Then NegativeValue = -20%

	The negative value then decays by 10% every minute.

	It can switch at any moment but to put the negative value into perspective:
	Takes 6 minutes for 20% to reduce to 10%.
	Takes 28 minutes for 20% to reduce to 1%.
	
Example 2:
	If SwitchingPrevention = 4 and accuracy of most profitable coin = 90%
	Then NegativeValue = -40%
	
	It takes 13 minutes for 40% to reduce to 10%.
	0.9 ^ 13 * 40 = 10
	

Determination of "biased" estimated profit:

The percentage amount that a reported estimated profit value is reduced, is based on the calculation below.
Percent Estimated Profit Reduction = (Margin of Error * SwitchingPrevention) / (Value that grows exponentially based on the number of minutes current miner has been running)

This means that the longer the current miner is running, the less MPM takes the Margin of Error into consideration and the less it reduces the estimated profit value. By adjusting the -SwitchingPrevention value up, you increase the effect the Margin of Error has on the calculation and, therefore, increase the amount of current miner run-time required to reduce this effect.

In practice, this explains why when you first launch MPM it may pick a pool/algorithm combo that has a lower value in the "Currency/Day" column, as it is favoring a more accurate combo. Over time, assuming the more profitable pool/algorithm stays more profitable, the accuracy will have less and less weight in the miner selection calculation process until MPM eventually switches over to it.

Please note that a new install of MultiPoolMiner has no historical information on which to build accurate "margin-of-error" values. MPM will, therefore, sometimes make less desirable miner selections and switch more often until it can gather enough coin data to stabilize its decision-making process.


====================================================================


MULTIPOOLMINER WEB GUI:


MultiPoolMiner has a built in Web GUI at http://localhost:3999 (port is 3999 unless you have changed the default API port)



====================================================================


MULTIPOOLMINER API:


MultiPoolMiner allows basic monitoring through its built in API.
API data is available at http://localhost:3999/<resource> (port is 3999 unless you have changed the default API port)

For a list of supported API commands open [MPM directory\]APIDocs.html with your web browser.


====================================================================


KNOWN ISSUES:

There are known issues with the following miners not submitting shares or show higher hashrate than what they actually do:
- NVIDIA_CCminerLyra2Z (deprecated)
- NVIDIA_CCminerLyra2RE2 (deprecated)
This is not a fault of MultiPoolMiner and nothing can be done on our end. Please raise an issue on their respective github pages. See FAQ#2 on how to exclude these if you wish to do so.


====================================================================


FREQUENTLY ASKED QUESTIONS:

Q1. How do I start using MultiPoolMiner?
A1. The 'start.bat' file is an example that shows how to run the script without prompting for a username. Amend it with your username/address/workername and other relevant details such as region. Ensure it is run as Administrator to prevent errors.

Q2. A miner crashes my computer or does not work correctly. I want to exclude it from mining/benchmarking. What should I do?
A2. Use the -excludeminername command to exclude certain miners you don't want to use. A full list of available miners and parameters used can be found here: https://multipoolminer.io/miners

Q3. Miner says CL device is missing (or not found). How do I resolve this issue?
A3. You most likely have NVIDIA cards in your rig. Open the start.bat in a text editor and look for '-devicename amd,nvidia,cpu' and change it to '-devicename nvidia,cpu'. This will disable the AMD exclusive miners and save you plenty of time when benchmarking. You can also exclude the cpu option if you don't want to mine with your processor.

Q4. I only want to mine certain algorithms even if they are not the most profitable. I want to exclude algorithms. How do I do that?
A4. Open the start.bat in a text editor and look for 'algorithm cryptonight,ethash,equihash,groestl,lyra2z,neoscrypt,pascal'. Delete the algorithms you don't want to mine. This can save you some time when benchmarking. You can include any of these or even all of them if you please but bear in mind this can result your earnings to be spread across many pools! 

Q5. MultiPoolMiner is XX% more profitable. What does this mean?
A5. It is showing you the stat for MultiPoolMiner vs the one miner. It means that the calculated earnings of MultiPoolMiner switching to different algorithms would be that much more profitable than if it had just mined that one particular algorithm the whole time. The number is still only an estimate of your earnings on the pool and may not directly reflect what you actually get paid. On MiningPoolHub and other multiple algorithm pools, coins have fluctuating values and MultiPoolMiner switches to the one that is the most profitable at that time. Because each pool has different delays in exchange and payout, the amount you actually earn my be very different. If there is a significant difference in percentage, you might want to reset the profitability stats by running the ResetProfit.bat file. Your actual (but still estimated) earning is shown in the second row.

Q6. I want to re-run the benchmarks (changed OC settings, added new cards, etc.)
A6. Simply run 'ResetBenchmark.bat' This deletes all files in the /Stats folder. This will force MultiPoolMiner to run the benchmarks again. If you only want to re-run a single benchmark for a coin or algorithm, locate the appropriate stat file for that particular coin or algorithm and delete it. Please note some of the miners can do multiple algorithms therefore have multiple stat files for the same miner and some of them create multiple stat files for the different configuration files they use.

Q7. How long does benchmarking take to finish?
A7. This is greatly dependant on the amount of selected algorithms and the number of device types chosen in the start.bat file. By default, each benchmark takes one minute. You can speed up benchmarking significantly by omitting unused device types. For example if you have a rig with AMD cards, you can tell MPM not to even launch the NVIDIA or CPU specific miner applications by removing these after the -devicename parameter in the start.bat file.

Q8. Is it possible to choose how many GPUs we want to allocate to mining or restrict mining on certain GPUs?
A8. This feature will possibly be implemented in the future (planned enhancement for MultiPoolMiner V3) but not yet supported by MultiPoolMiner.

Q9. MultiPoolMiner says it cannot find excavator.exe
A9. Excavator is developed by Nicehash and their EULA does not permit redistribution of their software which means you need to download Excavator yourself from https://github.com/nicehash/excavator/releases and place it in /Bin/Excavator/ (create the folder if does not exist). This is the permitted use of Excavator. Another solution is to delete the Excavator configuration file from the /Miners folder if you don't plan to use this miner.

Q10. MultiPoolMiner is taking up too much space on my drive
A10. Simply run 'RemoveLogs.bat' This will delete all unnecessary and/or old log files that can indeed take up a lot of space of your storage device. It is perfectly safe to do so if space is required.

Q11. What does 'ResetProfit.bat' do?
A11. This will reset your profit statistics and deletes all coin profibility data accumulated since MultiPoolMiner was first launched. This can be helpful when your predicted income stats (calculated average results) are broken which can happen when ie. an existing coin is added to a new exchange and the price falsely skyrockets due to low volume and liquidity. Bear in mind MultiPoolMiner becomes more accurate over time at calculating your profitability and running this scrypt will delete all that recorded data.

Q12. Why does MultiPoolMiner open multiple miners of the same type?
A12. Not all miners support multiple GPUs and this is a workaround to resolve this issue. MultiPoolMiner will try to open upto 6 instances of some of the miners to support systems with upto 6 GPUs or to overcome other problems found while testing. Doing so makes no difference in performance and donation amount to the miner sw developer (if applicable) will be the same percentage as if it was a single instance run for multiple GPUs ie. if one instance is run for five cards or five instances, one for each of the the five cards, that is still the same 1% donation NOT 5x1%.

Q13. MultiPoolMiner does not close miners properly (2 or more instances of the same miner accumulate over time)
A13. This is due to miner failure most likely caused by too much OVERCLOCKING. When miner fails it tries to recover which usually means restarting itself in the same window. This causes issues with the API connection to the miner and MultiPoolMiner thinks miner quit and launches another instance as a result. Due to default API port still being used by the first launched but failed miner, MPM can launch many instances of the same miner over time. This behaviour will be improved upon in the future but can only be completely solved by the user by lowering overclock to keep miners and the system stable.  

Q14. Is it possible to change the payout currency from BTC to something else when mining on yiimp-based pools such as Zpool, Hash Refinery, etc?
A14. Yes, see 'Advanced Configuration / To change payout currency of a pool'. However, this is not recommended as your payout will become uncertain as all other payout currencies are internally exchanged therefore you may end up losing your earnings due to pool never having enough coins to pay you!

Q15. How do I customise miners to better work with my cards?
A15. Some cards may require special parameters to be used in order to make them (more) stable, such as setting intensity for specific miners/algos/GPUs. This can be done by heading to the /Miners folder and editing the relevant miner files or via advanced constomization (see Advanced configuration for Miners -> Add custom miner commands). For example, for CcminerTpruvot.ps1 you can replace
"x17" = "" # X17
with:
"x17" = " -i 20" # X17 (mind the spaces! " -i 20")
to add intensity setting for that specific algorithm while used in conjuction with tpruvot's ccminer fork. This will result this specific miner on that specific algorithm will use the intensity setting of 20 which may help if you are experiencing driver crashes when using certain cards. Please search relevant forums for correct and recommended settings before changing anything!

Q16. I am getting: ErrorCode error = method(handle, name, <IntPtr>Marshal.SizeOf<T>(),h.AddrOfPinnedObject(), out size); 
A16. Microsoft .NET Framework 4.5.1 or later is required for MultiPoolMiner to function properly. Please update from here: https://www.microsoft.com/en-us/download/details.aspx?id=40773

Q17. Is there an option to split earnings? I want to mine 80% of the time to wallet A and 20% of the time to wallet B.
A17. This feature is not implemented, however, there are external services you can use to achieve the same such as https://coinsplit.io/

Q18. How to change fault tolerance limit to a higher percentage?
A18. Fault tolerance limit was implemented to detect unwanted negative or positive spikes in your hashrate caused by faulty miners or GPUs and prevent these statistics to be recorded to keep your benchmark data preserved in these unfortunate events. You should not feel the need to change this but first try to resolve the issues with your miners and/or devices. That said, if you are absolutely certain you want to change this, you can do so by amending the following line in Include.psm1:
    [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9)
    From:
    0.1), 0.9)
    To:
    0.3), 0.75)
This will change the fault tolerance limit from +/-10% to +30/-25%.

Q19. MultiPoolMiner is not mining the most profitable algorithm. Why?
A19. MPM version 2.7 introduced a smarter spike resistance for both of your hashrate and coin difficulty/price ratio. This feature will detect and handle mining accordingly to prevent you losing time and profit. The usual case is, if an algorithm's price fluctuates a lot, then the short time profit might appear to be higher, but by the time you have mined it for a period of time, the coins will be exchanged for a much lower price and your mining will be less profitable. This is due to the PPLNS(+) nature implemented in the pools. To mitigate this effect MPM uses an 24h mean price (if provided by the pool) when determininig the most profitable algorithm. [#712] [#713] [query re NH to be resolved/omitted]

Q20. I am getting the following error: "NetFirewallRule - Access denied"
A20. You cannot put MultiPoolMiner inside directorires such as Program Files. Extract it to a non-restricted or user-created folder such as Desktop, Downloads, Documents, C:\MPM\ etc.

Q21. My antivirus says the .zip package contains a virus or MultiPoolMiner tries to download viruses. What should I do?
A21. MultiPoolMiner is open-source and used by many users/rigs. It also downloads miners from github releases that are open-sourced projects. That means the code is readable and you can see for yourself it does not contain any viruses. Your antivirus generates false positives as the miner software used by MultiPoolMiner are often included in malicious programs to create botnets for someone who wants to earn a quick buck. There are other closed-source miner program included in the package such as the Claymore miners. These come from legendary ranked or trusted/respected members of the bitcointalk community and used by a large number of users/rigs worldwide. You can exlude these miners if you wish by following the instructions in FAQ#2 and delete their software from your system. 

Q22. How to disable dual-mining?
A22. Add '-SingleAlgoMining' to your start batch file or to the config file.
    
Q23. How to manually download miner binaries?
A23. Some miners binaries cannot be downloaded automatically by MPM (e.g. there is no direct download). In these cases you need to download and install them manually. First find the download link "Uri" in the miner file (they are all in the folder 'Miners') and download the binaries. Next locate the destination path "$Path". You need to create the required subdirectory in the 'Miners' folder. Finally unpack the downloaded binary to the destination directory. If the packed file contains subdirectories you must also copy them.


====================================================================


REPORTING AND MONITORING TERMS AND CONDITIONS & PRIVACY POLICY:

By enabling the Monitoring Service by setting the -MinerStatusURL to point to https://multipoolminer.io/monitor/miner.php as described in the Command Line Options section, you agree that the https://multipoolminer.io website can store relevant information about your mining rig(s) in its database that is directly accessible by anyone accessing the https://multipoolminer.io/monitor webpage with the corresponding wallet address (your BTC address set with the -wallet command). The following data is stored for each mining machine (rig) and overwritten in the database in each script-cycle determined by the -interval command:

BTC address: all data is stored under and identified by the Bitcoin address set with the -wallet command
WorkerName: the name of the worker you set using the -workername command, also used for sorting
MinerName: the current miner software the worker is running
Type: device type set using the -devicename command, also used for sorting
Pool: current pool(s) the worker is mining on
Path: the miner application's path starting from /Bin as root. We will not store other user data!
Active: time the worker has been active for
Algorithm: the current algorithm the worker is running
Current Speed: reported hashrate from the miner
Benchmark Speed: benchmarked hashrate for the current algorithm running
PID: process ID of the miner application being used
BTC/day: Estimated Bitcoin earnings per day

The monitoring service can change, evolve, be unavailable any time without prior notice. The contents of the database will NOT be shared with any third-parties but we reserve the right to create metrics out of it and use its contents to improve or promote our services and MultiPoolMiner. Credits to @grantemsley for the codebase.
