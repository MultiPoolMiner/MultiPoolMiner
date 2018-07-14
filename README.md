# MultiPoolMiner®
###### created by aaronsace 
###### **WEBSITE: [MultiPoolMiner.io](https://multipoolminer.io)**
###### **GITHUB: [https://github.com/MultiPoolMiner/](https://github.com/MultiPoolMiner/MultiPoolMiner/releases)**
###### **REDDIT: [/r/multipoolminer/](https://www.reddit.com/r/multipoolminer/)**
###### **TWITTER: [@multipoolminer](https://twitter.com/multipoolminer)**

###### Licensed under the GNU General Public License v3.0 - Permissions of this strong copyleft license are conditioned on making available complete source code of licensed works and modifications, which include larger works using a licensed work, under the same license. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights. https://github.com/MultiPoolMiner/MultiPoolMiner/blob/master/LICENSE

README.md is based on README.txt - updated on 08/07/2018 (dd/mm/yyyy) - latest version can be found here: https://github.com/MultiPoolMiner/MultiPoolMiner/blob/master/README.txt



## FEATURE SUMMARY

- **Monitors crypto mining pools and coins in real-time and finds the most profitable for your machine**
- **Controls any miner that is available via command line**
- **Supports benchmarking, multiple platforms (AMD, NVIDIA and CPU) and mining on A Hash Pool, BlazePool, BlockMasters, Hash Refinery, MiningPoolHub, Nicehash, YiiMP, ZergPool and Zpool pools**
- **Includes Watchdog Timer to detect and handle miner failures**

*Any bitcoin donations are greatly appreciated: 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH*



## INSTALLATION

1. Download the latest RELEASE (.zip package) from https://github.com/MultiPoolMiner/MultiPoolMiner/releases
2. Extract it to your Desktop (MultiPoolMiner will NOT work from folders such as "C:\Program Files\")
3. Make sure you have all pre-requisites installed/updated from the IMPORTANT NOTES section below.
4. Right-click on the (required) Start.bat file and open it with a Notepad application. Multiple start.bat files are included as examples.
5. Edit the Start.bat file with your details (such as YOUR username, wallet address, region, worker name, device type). New users should NOT edit anything else. Please see COMMAND LINE OPTIONS below for specification and further details.
6. Save and close the Start.bat file you just edited.
7. Launch the Start.bat file you just edited.
8. Let the benchmarking finish (you will be earning shares even during benchmarking).

Done. You are all set to mine the most profitable coins and maximise your profits using MultiPoolMiner.



## IMPORTANT NOTES

- It is not recommended but to upgrade from a previous version of MultiPoolMiner, you may simply copy the 'Stats' folder.
- Having PowerShell 6 installed is now a requirement. [Windows 64bit](https://github.com/PowerShell/PowerShell/releases/download/v6.0.2/PowerShell-6.0.2-win-x64.msi), [All other versions](https://github.com/PowerShell/PowerShell/releases)
- Microsoft .NET Framework 4.5.1 or later is required for MultiPoolMiner to function properly. [Web Installer](https://www.microsoft.com/en-us/download/details.aspx?id=40773)
- CCMiner (NVIDIA cards only) may need 'MSVCR120.dll' if you don't already have it: https://www.microsoft.com/en-gb/download/details.aspx?id=40784. Make sure that you install both the x86 and the x64 versions. 
- CCMiner (NVIDIA cards only) may need 'VCRUNTIME140.DLL' if you don't already have it: https://www.microsoft.com/en-us/download/details.aspx?id=48145. Make sure that you install both the x86 and the x64 versions. 
- It is highly recommended to set Virtual Memory size in Windows to at least 16 GB in multi-GPU systems: Computer Properties -> Advanced System Settings -> Performance -> Advanced -> Virtual Memory
- Please see the FAQ section on the bottom of this page before submitting bugs and feature requests on Github. https://github.com/MultiPoolMiner/MultiPoolMiner/issues 
- Logs and Stats are produced in text format; use them when submitting issues.
- Currently mining with upto 6 GPUs is fully supported. Where required advanced users can create additional or amend current miner files to support mining with more than 6 graphics cards.

	

## COMMAND LINE OPTIONS
###### (case-insensitive - except for BTC addresses, see *Sample Usage* section below for an example)

**-region [Europe/US/Asia]**
Choose your region or the region closest to you.

**-poolname [ahashpool, ahashpoolcoins, blazepool, blockmasters, blockmasterscoins, hashrefinery, miningpoolhub, miningpoolhubcoins, nicehash, yiimp, zergpool, zergpoolcoins, zpool, zpoolcoins]**
The following pools are currently supported (in alphabetical order):

	- AHashPool / AHashPoolCoins https://www.ahashpool.com/

	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below)

	- BlazePool http://www.blazepool.com/

	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below)

	- BlockMasters / BlockMastersCoins http://www.blockmasters.co/

	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below), or any currency available in API (Advanced configuration via Config.txt required, see below)
	  
	  Pool allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via Config.txt required, see below)

	- HashRefinery http://pool.hashrefinery.com

	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below)

	- MiningPoolHub / MiningPooHubCoins https://miningpoolhub.com/

	  - 'miningpoolhub' parameter uses the 17xxx ports therefore allows the pool to decide on which coin is mined of a specific algorithm
	  - 'miningpoolhubcoins' allows for MultiPoolMiner to calculate and determine what is mined from all of the available coins (20xxx ports). 
	  Usage of the 'miningpoolhub' parameter is recommended as the pool have internal rules against switching before a block is found therefore prevents its users losing shares submitted due to early switching. A registered account is required when mining on MiningPoolHub (username must be provided using the -username command, see below).
	  
	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below), or any currency available in API (Advanced configuration via Config.txt required, see below)
	  
	  Pool allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via Config.txt required, see below)

	- Nicehash https://www.nicehash.com/

	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below)

	- YiiMP http://yiimp.eu/

	  Note: Yiimp is not an auto-exchange pool. Do NOT mine with a BTC address. A separate wallet address for each mined currency must be provided in config.txt (see below)

	- ZergPool http://zergpool.eu

	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below), or any currency available in API (Advanced configuration via Config.txt required, see below)
	  
	  Pool allows mining selected coins only, e.g mine only ZClassic (Advanced configuration via Config.txt required, see below)

	- Zpool http://www.zpool.ca/

	  Payout in BTC (Bitcoin address must be provided using the -wallet command, see below), or any currency available in API (Advanced configuration via Config.txt required, see below)
	  
	***IMPORTANT**: For the list of default configured pools consult 'start.bat.' This does not rule out other pools to be included. Selecting multiple pools is allowed and will be used on a failover basis OR if first specified pool does not support that algorithm/coin. See the -algorithm command below for further details and example.*

**-ExcludePoolName**
Same as the *-poolname* command but it is used to exclude unwanted mining pools (please see above).

**-UserName**
Your username you use to login to MiningPoolHub.

**-WorkerName**
To identify your mining rig.

**-Wallet**
Your Bitcoin payout address. Required when mining on AhashPool, BlazePool, Hash Refinery, Nicehash and Zpool.
	
**-SSL**
Specifying the -ssl command (without a boolean value of true or false) will restrict the miner application list to include only the miners that support secure connection.

**-DeviceName**
Choose the relevant GPU(s) and/or CPU mining.  [CPU, GPU, GPU#02, AMD, NVIDIA, AMD#02, OpenCL#03#02 etc.]

**-Algorithm**

Supported algorithms sorted by pool can be found at https://multipoolminer.io/algorithms

The following algorithms are currently supported: 

    Bitcore, Blakecoin, Blake2s, BlakeVanilla, C11, CryptoNightV7, Ethash, X11, Decred, Equihash, Groestl, HMQ1725, HSR, JHA, Keccak, Lbry, Lyra2RE2, Lyra2z, MyriadGroestl, NeoScrypt, Pascal, Phi, Phi2, Phi1612, Polytimos, Quark, Qubit, Scrypt, SHA256, Sib, Skunk, Skein, Timetravel, Tribus, Veltor, X11, X12, X11evo, X16R, X16S, X17, Yescrypt
* Note that the list of supported algorithms can change depending on the capabilities of the supported miner binaries. Some algos are now being mined with ASICs and are no longer profitable when mined with CPU/GPU and will get removed from MPM.
#### Special parameters: 
- **ethash2gb** - can be profitable for older GPUs that have 2GB or less GDDR memory. It includes ethash coins that have a DAG file size of less than 2GB (and will be mined when most profitable). Ethereum and a few other coins have surpassed this size therefore cannot be mined with older cards.
- **decrednicehash** - if you want to include non-dual, non-Claymore Decred mining on Nicehash. NH created their own implementation of Decred mining protocol.

*Note that the pool selected also needs to support the required algorithm(s) or your specified pool (-poolname) will be ignored when mining certain algorithms. The -algorithm command is higher in execution hierarchy and can override pool selection. This feature comes handy when you mine on Zpool but also want to mine ethash coins (which is not supported by Zpool). **WARNING!** If you add all algorithms listed above, you may find your earnings spread across multiple pools regardless what pool(s) you specified with the -poolname command.*

**-ExcludeAlgorithm**
Same as the *-algorithm* command but it is used to exclude unwanted algorithms (please see above). Supported algorithms sorted by pool can be found at https://multipoolminer.io/algorithms

**-MinerName**
Specify to only include (restrict to) certain miner applications. A full list of available miners and parameters used can be found here: https://multipoolminer.io/miners

**-ExcludeMinerName**
Exclude certain miners you don't want to use. This is useful if a miner is causing issues with your machine. A full list of available miners and parameters used can be found here: https://multipoolminer.io/miners
Important: Newer miners, e.g. ClaymoreEthash create several child-miner names, e.g. ClaymoreEthash-GPU#01-Pascal-40. These can also be used with '-ExcludeMinerName'.
	
**-Currency [BTC, USD, EUR, GBP, ETH ...]**
Choose the default currency or currencies your profit stats will be shown in.

**-Interval**
MultiPoolMiner's update interval in seconds. This is a universal timer for running the entire script (downloading/processing APIs, calculation etc).  It also determines how long a benchmark is run for each miner file (miner/algorithm/coin). Default is 60.

**-Delay**
Specify the number of seconds required to pass before opening each miner. It is useful when cards are more sensitive to switching and need some extra time to recover (eg. clear DAG files from memory)

**-Donate**
Donation of mining time in minutes per day to aaronsace. Default is 24, minimum is 10 minutes per day (less than 0.7% fee). The downloaded miner software can have their own donation system built in. Check the readme file of the respective miner used for more details.

**-Proxy**
Specify your proxy address if applicable, i.e http://192.0.0.1:8080

**-Watchdog**
Include this command to enable the watchdog feature which detects and handles miner and other related failures.
It works on a unified interval that is defaulted to 60 seconds. Watchdog timers expire if three of those intervals pass without being kicked. There are three stages as to what action is taken when watchdog timers expire and is determined by the number of related expired timers.
- Stage 1: when 1 timer expires relating to one miner/algorithm combination, the one miner/algorithm combination is kicked
- Stage 2: when 2 timers expire relating to one miner file, the one miner file is kicked
- Stage 3: when 3 timers expire relating to one pool, the pool is kicked

Watchdog timers reset after three times the number of seconds it takes to get to stage 3.

**-MinerstatusURL** https://multipoolminer.io/monitor/miner.php
Report and monitor your mining rig's status by including the command above. Wallet address must be set even if you are only using MiningPoolHub as a pool. You can access the reported information by entering your wallet address on the https://multipoolminer.io/monitor web address. By using this service you understand and accept the terms and conditions detailed in this document (further below). 

**-MinerstatusKey**
By default the MPM monitor uses the BTC address (-wallet) to identify your mining machine (rig). Use --minerstatuskey [your-miner-status-key] to anonymize your rig. To get your minerstatuskey goto to https://multipoolminer.io/monitor

**-SwitchingPrevention**
Since version 2.6, the delta value (integer) that was used to determine how often MultiPoolMiner is allowed to switch, is now user-configurable on a scale of 1 to infinity on an intensity basis. Default is 1 (Start.bat default is 2). Recommended values are 1-10 where 1 means the most frequent switching and 10 means the least switching. Please note setting this value to zero (0) will not turn this function off! Please see further explanation in MULTIPOOLMINER'S LOGIC section below. 

**-DisableAutoUpdate**
By default MPM will perform an automatic update on startup if a newer version is found. Set to 'true' to disable automatic update to latest MPM version. 

**-ShowMinerWindow**
By default MPM hides most miner windows as to not steal focus (Miners of API type 'Wrapper' will remain hidden). All miners write their output to files in the Log folder. Set to 'true' to show miner windows.

**-UseFastestMinerPerAlgoOnly**
Use only use fastest miner per algo and device index. E.g. if there are 2 or more miners available to mine the same algo, only the fastest will ever be used, the slower ones will also be hidden in the summary screen.

**-ShowPoolBalances**
Display the balances of all enabled pools (excluding those that are excluded with 'ExcludeMinerName') on the summary screen and in the web GUI.
Note: Only balances in BTC are listed, other currencies are currently not supported.

**-ShowPoolBalancesExcludedPools**
Display the balances of all pools (including those that are excluded with 'ExcludeMinerName') on the summary screen and in the web GUI.
Note: Only balances in BTC are listed, other currencies are currently not supported.

**-ConfigFile [Path\ConfigFile.txt]**
The default config file name is '.\default.txt'
If the config file does not exist MPM will create a config file with default values. If the file name does not have an extension MPM will add .txt file name extension.
By default MPM will use the values from the command line. If you hardcode config values directly in the config file, then these values will override the command line parameters (see Advanced Configuration).



##SAMPLE USAGE
#####(check "start.bat" file in root folder)

@cd /d %~dp0

@if not "%GPU_FORCE_64BIT_PTR%"=="1" (setx GPU_FORCE_64BIT_PTR 1) > nul
@if not "%GPU_MAX_HEAP_SIZE %"=="100" (setx GPU_MAX_HEAP_SIZE 100) > nul
@if not "%GPU_USE_SYNC_OBJECTS%"=="1" (setx GPU_USE_SYNC_OBJECTS 1) > nul
@if not "%GPU_MAX_ALLOC_PERCENT%"=="100" (setx GPU_MAX_ALLOC_PERCENT 100) > nul
@if not "%GPU_SINGLE_ALLOC_PERCENT%"=="100" (setx GPU_SINGLE_ALLOC_PERCENT 100) > nul
@if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

@set "command=& .\multipoolminer.ps1 -wallet 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb -username aaronsace -workername multipoolminer -region europe -currency btc,usd,eur -devicename amd,nvidia,cpu -poolname miningpoolhubcoins,zpool,nicehash -algorithm blake2s,cryptonightV7,decrednicehash,ethash,ethash2gb,equihash,groestl,keccak,lbry,lyra2re2,lyra2z,neoscrypt,pascal,sib,skunk -donate 24 -watchdog -minerstatusurl https://multipoolminer.io/monitor/miner.php -switchingprevention 2"

start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log 'MultiPoolMiner_\d\d\d\d-\d\d-\d\d\.txt' -sort '^[^_]*_' -quickstart"
start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log '^((?!MultiPoolMiner_\d\d\d\d-\d\d-\d\d_\d\d-\d\d-\d\d\.txt).)*$' -sort '^[^_]*_' -quickstart"

pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
msiexec -i https://github.com/PowerShell/PowerShell/releases/download/v6.0.2/PowerShell-6.0.2-win-x64.msi -qb!
pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

pause
############ END OF CONTENT OF START.BAT ############



## ADVANCED CONFIGURATION

### Advanced config options are available via config file

MPM supports customized configuration via config files. The default config file name is '.\Default.txt'.
If you do not include the command line parameter -ConfigFile [Path\FileName.txt] the MPM will use the default file name. 

If the config file does not exist MPM will create a config file with default values. If the file name does not have an extension MPM will add .txt file name extension.
The default config file contains only the parameters which are also available per command line. 
Note: More config items are added to the live configuration during runtime. For full list of available config items at runtime see the API at http://localhost:3999/config. All items could also be added manually to the config file (use with caution as this might lead to unpredictable results).

The config file is a JSON file and human readable / editable. A good primer for understanding the JSON structure can be found here: https://www.tutorialspoint.com/json/index.htm

Warning: The JSON file structure is very fragile - every comma counts, so be careful when editing this file manually. To test the validity of the structure use a web service like https://jsonblob.com (copy/paste the complete file).

### Sample content of 'Config.txt'

```
{
    "VersionCompatibility":  "3",
    "Wallet":  "$Wallet",
    "UserName":  "$UserName",
    "WorkerName":  "$WorkerName",
    "API_ID":  "$API_ID",
    "API_Key":  "$API_Key",
    "Interval":  "$Interval",
    "Region":  "$Region",
    "SSL":  "$SSL",
    "DeviceName":  "$DeviceName",
    "Algorithm":  "$Algorithm",
    "MinerName":  "$MinerName",
    "PoolName":  "$PoolName",
    "ExcludeAlgorithm":  "$ExcludeAlgorithm",
    "ExcludeMinerName":  "$ExcludeMinerName",
    "ExcludePoolName":  "$ExcludePoolName",
    "Currency":  "$Currency",
    "Donate":  "$Donate",
    "Proxy":  "$Proxy",
    "Delay":  "$Delay",
    "Watchdog":  "$Watchdog",
    "MinerStatusUrl":  "$MinerStatusUrl",
    "MinerStatusKey":  "$MinerStatusKey",
    "SwitchingPrevention":  "$SwitchingPrevention",
    "DisableAutoUpdate":  "$DisableAutoUpdate",
    "ShowMinerWindow":  "$ShowMinerWindow",
    "UseFastestMinerPerAlgoOnly":  "$UseFastestMinerPerAlgoOnly",
    "IgnoreCosts":  "$IgnoreCosts",
    "ShowPoolBalances":  "$ShowPoolBalances",
    "ShowPoolBalancesExcludedPools":  "$ShowPoolBalancesExcludedPools",
    "Pools":  {

              },
    "Miners":  {

               }
}
```

There is a section for Pools, Miners and a general section

### Advanced configuration for Pools

Settings for each configured pool are stored in its own subsection. These settings are only valid for the named pool.

#### To change payout currency of a pool

If a pool allows payout in another currency than BTC you can change this.
Note: Not all pools support this, for more information consult the pools web page

For each pool you can statically add a section similar to this (see http://localhost:3999/config):

    "Zpool": {
        "BTC": "$Wallet",
        "Worker": "$WorkerName"
    }

The payout currency is defined by this line:
"BTC": "$Wallet", (MPM will use the the wallet address from the start.bat file)

E.g. to change the payout currency for Zpool to LiteCoin replace the line for BTC with "LTC": "<YOUR_LITECOIN_ADDRESS>", (of course you need to insert a real LTC address)

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName"
    }



### Advanced configuration for Miners

Settings for each configured miner are stored in its own subsection. These settings are only valid for the named miner.


### Advanced general configuration

Settings in this section affect the overall behaviour of MPM.

#### To show miner windows

By default MPM hides most miner windows as to not steal focus . All miners write their output to files in the Log folder.

To show the miner windows add '"ShowMinerWindow":  true' to the general section:

{
    ...
    "SwitchingPrevention":  "$SwitchingPrevention",
    "ShowMinerWindow":  true,
    ...
}
Note: Showing the miner windows disables writing the miner output to log files. Miners of API type 'Wrapper' will remain hidden.

#### Pool Balances

MPM can gather the pending BTC balances from all configured pools.

To display the balances of all enabled pools (excluding those that are excluded with 'ExcludeMinerName') on the summary screen and in the web GUI add '"ShowPoolBalances":  true' to the general section:
{
    ...
	"ShowPoolBalances":  true
    ...
}
	
To display the balances of all pools (including those that are excluded with 'ExcludeMinerName') on the summary screen and in the web GUI '"ShowPoolBalances":  true' to the general section:
{
    ...
	"ShowPoolBalancesExcludedPools":  true
    ...
}
Note: Only balances in BTC are listed, other currencies are currently not supported.



## MULTIPOOLMINER'S LOGIC

### General overview:

- The various pools estimated profit values (visible on their respective web pages) are determined by the pools themselves. Each algorithm's estimated profit value is a combination of the current mined coin's last known exchange value in BTC, the coins network difficulty (or network hashrate) and the current pools overall hashrate.
- MPM polls all pools it knows about (enabled or not) on a pre-defined interval (default is every 60 seconds) to gather the pools estimated profit for all of its advertised algorithms. As these profits change at each polling interval (based on the three factors mentioned above), MPM tracks how often and how drastic the changes are per algorithm and records this per-algorithm as a "fluctuation" metric. This fluctuation or margin-of-error is represented in MPM's output as "accuracy". e.g. An algorithm whose reported estimated profit values have a 90% accuracy can be conversely thought of as having a 10% margin-of-error.
- As MPM repeatedly polls the pools over time, the more correct the reported accuracy (i.e. margin of error) becomes for a particular pools algorithm.
- Due to the nature of pool-based mining, it is generally considered better to mine longer on algorithms that are most profitable with low margin-of-error over time (i.e. high accuracy). Technically, this takes into account concepts like PPLNS vs. PPS, ramp-up time for reported pool hash rate vs. miner reported hash rates, new/cheap coins with wildly fluctuating exchange prices etc.

### Switching (or anti-switching) logic:

- MPM retrieves the estimated profit for all pools/algorithms and filters out any undesired algorithms.
- The estimated profit for each pool/algorithm combo is reduced by a calculated percentage amount (see below for specifics) to determine a "biased" estimated profit.
- The "biased" estimated profits for each enabled pool/algorithm are combined with the benchmark hashrates previously calculated for all miners to calculate potential profit for your specific rig.
- The most profitable miner/algorithm/pool combination for your rig is selected and (if it isn't already running) it is launched.
- MPM idles for a pre-defined interval of time (default 60 seconds), then repeats the steps above.

##### **Formula:**

    [Price] x (1 - ([Fluctuation] x [Switching Prevention] x 0.9^[Intervals Past]))
    i.e. 123 x (1 - (0.2 x 2 x 0.9^5)
    
where:

    123 is BTC
    1 is 100%
    0.2 is 80% accuracy
    0.9 is 10% reduction
    5 is minutes if interval is 60 seconds

##### **Example 1:**

	If SwitchingPrevention = 2 and accuracy of most profitable coin = 90%
	Then NegativeValue = -20%

	The negative value then decays by 10% every minute.

	It can switch at any moment but to put the negative value into perspective:
	Takes 6 minutes for 20% to reduce to 10%.
	Takes 28 minutes for 20% to reduce to 1%.
	
##### **Example 2:**

	If SwitchingPrevention = 4 and accuracy of most profitable coin = 90%
	Then NegativeValue = -40%
	
	It takes 13 minutes for 40% to reduce to 10%.
	0.9 ^ 13 * 40 = 10
	

### Determination of "biased" estimated profit:

The percentage amount that a reported estimated profit value is reduced, is based on the calculation below.

Percent Estimated Profit Reduction = (Margin of Error * SwitchingPrevention) / (Value that grows exponentially based on the number of minutes current miner has been running)

This means that the longer the current miner is running, the less MPM takes the Margin of Error into consideration and the less it reduces the estimated profit value. By adjusting the -SwitchingPrevention value up, you increase the effect the Margin of Error has on the calculation and, therefore, increase the amount of current miner run-time required to reduce this effect.

In practice, this explains why when you first launch MPM it may pick a pool/algorithm combo that has a lower value in the "Currency/Day" column, as it is favoring a more accurate combo. Over time, assuming the more profitable pool/algorithm stays more profitable, the accuracy will have less and less weight in the miner selection calculation process until MPM eventually switches over to it.

*Please note, a new install of MultiPoolMiner has no historical information on which to build accurate "margin-of-error" values. MPM will, therefore, sometimes make less desirable miner selections and switch more often until it can gather enough coin data to stabilize its decision-making process.*



MULTIPOOLMINER API

## MultiPoolMiner allows basic monitoring through its built in API.

API data is available at http://localhost:3999/<resource>

For a list of supported API commands open APIDocs.html with your web browser.



## KNOWN ISSUES

There are known issues with the following miners not submitting shares or show higher hashrate than what they actually do:
- CCminerLyra2z
- CCminerLyra2RE2

This is not a fault of MultiPoolMiner and nothing can be done on our end. Please raise an issue on their respective github pages. See FAQ#2 on how to exclude these if you wish to do so.



## FREQUENTLY ASKED QUESTIONS

###### Q1. How do I start using MultiPoolMiner?
###### A1. The 'start.bat' file is an example that shows how to run the script without prompting for a username. Amend it with your username/address/workername and other relevant details such as region. Ensure it is run as Administrator to prevent errors.

###### Q2. A miner crashes my computer or does not work correctly. I want to exclude it from mining/benchmarking. What should I do?
###### A2. Use the -excludeminername command to exclude certain miners you don't want to use. A full list of available miners and parameters used can be found here: https://multipoolminer.io/miners

###### Q3. Miner says CL device is missing (or not found). How do I resolve this issue?
###### A3. You most likely have NVIDIA cards in your rig. Open the start.bat in a text editor and look for '-devicename amd,nvidia,cpu' and change it to '-devicename nvidia,cpu'. This will disable the AMD exclusive miners and save you plenty of time when benchmarking. You can also exclude the cpu option if you don't want to mine with your processor.

###### Q4. I only want to mine certain algorithms even if they are not the most profitable. I want to exclude algorithms. How do I do that?
###### A4. Open the start.bat in a text editor and look for '-algorithm cryptonightv7,ethash,equihash,groestl,lyra2z,neoscrypt,pascal'. Delete the algorithms you don't want to mine. This can save you some time when benchmarking. You can include any of these or even all of them if you please but bear in mind this can result your earnings to be spread across many pools! 

###### Q5. MultiPoolMiner is XX% more profitable. What does this mean?
###### A5. It is showing you the stat for MultiPoolMiner vs the one miner. It means that the calculated earnings of MultiPoolMiner switching to different algorithms would be that much more profitable than if it had just mined that one particular algorithm the whole time. The number is still only an estimate of your earnings on the pool and may not directly reflect what you actually get paid. On MiningPoolHub and other multiple algorithm pools, coins have fluctuating values and MultiPoolMiner switches to the one that is the most profitable at that time. Because each pool has different delays in exchange and payout, the amount you actually earn my be very different. If there is a significant difference in percentage, you might want to reset the profitability stats by running the ResetProfit.bat file. Your actual (but still estimated) earning is shown in the second row.

###### Q6. I want to re-run the benchmarks (changed OC settings, added new cards, etc.)
###### A6. Simply run 'ResetBenchmark.bat' This deletes all files in the /Stats folder. This will force MultiPoolMiner to run the benchmarks again. If you only want to re-run a single benchmark for a coin or algorithm, locate the appropriate stat file for that particular coin or algorithm and delete it. Please note some of the miners can do multiple algorithms therefore have multiple stat files for the same miner and some of them create multiple stat files for the different configuration files they use.

###### Q7. How long does benchmarking take to finish?
###### A7. This is greatly dependant on the amount of selected algorithms and the number of device types chosen in the start.bat file. By default, each benchmark takes one minute. You can speed up benchmarking significantly by omitting unused device types. For example if you have a rig with AMD cards, you can tell MPM not to even launch the NVIDIA or CPU specific miner applications by removing these after the -devicename parameter in the start.bat file.

###### Q8. Is it possible to choose how many GPUs we want to allocate to mining or restrict mining on certain GPUs?
###### A8. This feature will possibly be implemented in the future (planned enhancement for MultiPoolMiner V3) but not yet supported by MultiPoolMiner.

###### Q9. MultiPoolMiner says it cannot find excavator.exe
###### A9. Excavator is developed by Nicehash and their EULA does not permit redistribution of their software which means you need to download Excavator yourself from https://github.com/nicehash/excavator/releases and place it in /Bin/Excavator/ (create the folder if does not exist). This is the permitted use of Excavator. Another solution is to delete the Excavator configuration file from the /Miners folder if you don't plan to use this miner.

###### Q10. MultiPoolMiner is taking up too much space on my drive
###### A10. Simply run 'RemoveLogs.bat' This will delete all unnecessary and/or old log files that can indeed take up a lot of space of your storage device. It is perfectly safe to do so if space is required.

###### Q11. What does 'ResetProfit.bat' do?
###### A11. This will reset your profit statistics and deletes all coin profibility data accumulated since MultiPoolMiner was first launched. This can be helpful when your predicted income stats (calculated average results) are broken which can happen when ie. an existing coin is added to a new exchange and the price falsely skyrockets due to low volume and liquidity. Bear in mind MultiPoolMiner becomes more accurate over time at calculating your profitability and running this scrypt will delete all that recorded data.

###### Q12. Why does MultiPoolMiner open multiple miners of the same type?
###### A12. Not all miners support multiple GPUs and this is a workaround to resolve this issue. MultiPoolMiner will try to open upto 6 instances of some of the miners to support systems with upto 6 GPUs or to overcome other problems found while testing. Doing so makes no difference in performance and donation amount to the miner sw developer (if applicable) will be the same percentage as if it was a single instance run for multiple GPUs ie. if one instance is run for five cards or five instances, one for each of the the five cards, that is still the same 1% donation NOT 5x1%.

###### Q13. MultiPoolMiner does not close miners properly (2 or more instances of the same miner accumulate over time)
###### A13. This is due to miner failure most likely caused by too much OVERCLOCKING. When miner fails it tries to recover which usually means restarting itself in the same window. This causes issues with the API connection to the miner and MultiPoolMiner thinks miner quit and launches another instance as a result. Due to default API port still being used by the first launched but failed miner, MPM can launch many instances of the same miner over time. This behaviour will be improved upon in the future but can only be completely solved by the user by lowering overclock to keep miners and the system stable.  

###### Q14. Is it possible to change the payout currency from BTC to something else when mining on yiimp-based pools such as Zpool, Hash Refinery, etc?
###### A14. Yes, see https://github.com/MultiPoolMiner/MultiPoolMiner#to-change-payout-currency-of-a-pool. However this is not recommended as your payout will become uncertain as all other payout currencies are internally exchanged therefore you may end up losing your earnings due to pool never having enough coins to pay you!

###### Q15. How do I customise miners to better work with my cards?
###### A15. Some cards may require special parameters to be used in order to make them (more) stable, such as setting intensity for specific miners/algos/GPUs. This can be done by heading to the /Miners folder and editing the relevant miner files. For example, for CcminerTpruvot.ps1 you can replace (mind the spaces!)
    "x17" = "" # X17

###### with:

    "x17" = " -i 20" # X17 

###### to add intensity setting for that specific algorithm while used in conjuction with tpruvot's ccminer fork. This will result this specific miner on that specific algorithm will use the intensity setting of 20 which may help if you are experiencing driver crashes when using certain cards. Please search relevant forums for correct and recommended settings before changing anything!

###### Q16. I am getting: 
    ErrorCode error = method(handle, name, <IntPtr>Marshal.SizeOf<T>(),h.AddrOfPinnedObject(), out size);
    
###### A16. Microsoft .NET Framework 4.5.1 or later is required for MultiPoolMiner to function properly. [Web Installer](https://www.microsoft.com/en-us/download/details.aspx?id=40773)

###### Q17. Is there an option to split earnings? I want to mine 80% of the time to wallet A and 20% of the time to wallet B.
###### A17. This feature is not implemented, however, there are external services you can use to achieve the same such as [coinsplit.io/](https://coinsplit.io/)

###### Q18. How to change fault tolerance limit to a higher percentage?
###### A18. Fault tolerance limit was implemented to detect unwanted negative or positive spikes in your hashrate caused by faulty miners or GPUs and prevent these statistics to be recorded to keep your benchmark data preserved in these unfortunate events. You should not feel the need to change this but first try to resolve the issues with your miners and/or devices. That said, if you are absolutely certain you want to change this, you can do so by amending the following line in Include.psm1:
    [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9)
    
###### From:
    0.1), 0.9)
###### TO:
    0.3), 0.75)

###### This will change the fault tolerance limit from +/-10% to +30/-25%.

###### Q19. MultiPoolMiner is not mining the most profitable algorithm. Why?
###### A19. MPM version 2.7 introduced a smarter spike resistance for both of your hashrate and coin difficulty/price ratio. This feature will detect and handle mining accordingly to prevent you losing time and profit. The usual case is, if an algorithm's price fluctuates a lot, then the short time profit might appear to be higher, but by the time you have mined it for a period of time, the coins will be exchanged for a much lower price and your mining will be less profitable. This is due to the PPLNS(+) nature implemented in the pools. To mitigate this effect MPM uses an 24h mean price (if provided by the pool) when determininig the most profitable algo. (#712, #713, query re NH to be resolved/omitted)

###### Q20. I am getting the following error: "NetFirewallRule - Access denied"
###### A20. You cannot put MultiPoolMiner inside directorires such as Program Files. Extract it to a non-restricted or user-created folder such as Desktop, Downloads, Documents, C:\MPM\ etc.

###### Q21. My antivirus says the .zip package contains a virus or MultiPoolMiner tries to download viruses. What should I do?
###### A21. MultiPoolMiner is open-source and used by many users/rigs. It also downloads miners from github releases that are open-sourced projects. That means the code is readable and you can see for yourself it does not contain any viruses. Your antivirus generates false positives as the miner software used by MultiPoolMiner are often included in malicious programs to create botnets for someone who wants to earn a quick buck. There are other closed-source miner program included in the package such as the Claymore miners. These come from legendary ranked or trusted/respected members of the bitcointalk community and used by a large number of users/rigs worldwide. You can exlude these miners if you wish by following the instructions in FAQ#2 and delete their software from your system. 

###### Q22. How to disable dual-mining?
###### A22. Make sure NOT to include any of the the following parameters in your start.bat after *-algorithm* or add them after the *-ExludeAlgorithm* command: blake2s, decred, keccak, pascal, lbry, decrednicehash

###### Q23. How to download and install missing miner binaries?
###### A23. Some miners binaries cannot be downloaded automatically by MPM (e.g. there is no direct download). In these cases you need to download and install them manually. First find the download link "Uri" in the miner file (they are all in the folder 'Miners') and download the binaries. Next locate the destination path "$Path". You need to create the required subdirectory in the 'Miners' folder.  Finally unpack the downloaded binary to the destination directory. If the packed file contains subdirectories you must also copy them.


## REPORTING AND MONITORING
##### TERMS AND CONDITIONS & PRIVACY POLICY

###### By enabling the Monitoring Service by setting the *-MinerStatusURL* to point to *https://multipoolminer.io/monitor/miner.php* as described in the **Command Line Options** section, you agree that the https://multipoolminer.io website can store relevant information about your mining rig(s) in its database that is directly accessible by anyone accessing the https://multipoolminer.io/monitor webpage with the corresponding wallet address (your BTC address set with the *-wallet* parameter, alternatively you can use *-minerstatuskey* parameter). The following data is stored for each mining machine (rig) and overwritten in the database in each script-cycle determined by the *-interval* parameter.

###### **BTC address:** all data is stored under and identified by the Bitcoin address set with the -wallet command
###### **WorkerName:** the name of the worker you set using the -workername command, also used for sorting
###### **MinerName:** the current miner software the worker is running
###### **Type:** device type set using the -devicename command, also used for sorting
###### **Pool:** current pool(s) the worker is mining on
###### **Path:** the miner application's path starting from /Bin as root. We will not store other user data!
###### **Active:** time the worker has been active for
###### **Algorithm:** the current algorithm the worker is running
###### **Current Speed:** reported hashrate from the miner
###### **Benchmark Speed:** benchmarked hashrate for the current algorithm running
###### **PID:** process ID of the miner application being used
###### **BTC/day:** Estimated Bitcoin earnings per day

###### *The monitoring service can change, evolve, be unavailable any time without prior notice. The contents of the database will NOT be shared with any third-parties but we reserve the right to create metrics out of it and use its contents to improve or promote our services and MultiPoolMiner. Credits to @grantemsley for the codebase.*

