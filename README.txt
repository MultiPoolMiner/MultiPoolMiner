====================================================================
  __  __       _ _   _ _____            _ __  __ _                 
 |  \/  |     | | | (_)  __ \          | |  \/  (_)                
 | \  / |_   _| | |_ _| |__) |__   ___ | | \  / |_ _ __   ___ _ __ 
 | |\/| | | | | | __| |  ___/ _ \ / _ \| | |\/| | | '_ \ / _ \ '__|
 | |  | | |_| | | |_| | |  | (_) | (_) | | |  | | | | | |  __/ |   
 |_|  |_|\__,_|_|\__|_|_|   \___/ \___/|_|_|  |_|_|_| |_|\___|_|   
 
====================================================================
MultiPoolMiner - created by aaronsace 
LINK: https://multipoolminer.io

Licensed under the GNU General Public License v3.0
Permissions of this strong copyleft license are conditioned on making available complete source code of licensed works and modifications, which include larger works using a licensed work, under the same license. Copyright and license notices must be preserved. Contributors provide an express grant of patent rights. https://github.com/MultiPoolMiner/MultiPoolMiner/blob/master/LICENSE

README.txt - updated on 27/12/2017 - v1.21.8 - latest version can be found here: https://github.com/MultiPoolMiner/MultiPoolMiner/blob/master/README.txt

====================================================================


FEATURE SUMMARY:

- Monitors crypto mining pools and coins in real-time and finds the most profitable for your machine
- Controls any miner that is available via command line
- Supports benchmarking, multiple platforms (AMD, NVIDIA and CPU) and mining on MiningPoolHub, Zpool, Hash Refinery and Nicehash (Ahashpool support is coming soon)
- Includes Watchdog Timer to detect and handle miner failures

Any bitcoin donations are greatly appreciated: 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH 


====================================================================


IMPORTANT NOTES:

- It is not recommended but to upgrade from a previous version of MultiPoolMiner, you may simply copy the 'Stats' folder.
- Having PowerShell 6 installed is now a requirement. Windows 64bit: https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-rc.2/PowerShell-6.0.0-rc.2-win-x64.msi, ALL OTHER VERSIONS: https://github.com/PowerShell/PowerShell/releases
- Microsoft .NET Framework 4.5.1 or later is required for MultiPoolMiner to function properly. Please update from here: https://www.microsoft.com/en-us/download/details.aspx?id=40773
- CCMiner (NVIDIA cards only) may need 'MSVCR120.dll' if you don't already have it: https://www.microsoft.com/en-gb/download/details.aspx?id=40784
- CCMiner (NVIDIA cards only) may need 'VCRUNTIME140.DLL' if you don't already have it: https://www.microsoft.com/en-us/download/details.aspx?id=48145
- You may need 'excavator.exe' if you don't already have it: https://github.com/nicehash/excavator/releases
- It is highly recommended to set Virtual Memory size in Windows to at least 16 GB in multi-GPU systems: Computer Properties -> Advanced System Settings -> Performance -> Advanced -> Virtual Memory
- Please see the FAQ section on the bottom of this page before submitting bugs and feature requests on Github. https://github.com/MultiPoolMiner/MultiPoolMiner/issues 
- Logs and Stats are produced in text format; use them when submitting issues.
- Currently mining with upto 6 GPUs is fully supported. Where required advanced users can create additional or amend current miner files to support mining with more than 6 graphics cards.

	
====================================================================


COMMAND LINE OPTIONS (case-insensitive, see Sample Usage section below for an example):

-region [Europe/US/Asia]
	Choose your region or the region closest to you.

-poolname [miningpoolhub,miningpoolhubcoins,zpool,hashrefinery,nicehash]
	The following pools are currently supported: 
	## MiningPoolHub https://miningpoolhub.com/ 
	        The 'miningpoolhub' parameter uses the 17xxx ports therefore allows the pool to decide on which coin is mined of a specific algorithm, while 'miningpoolhubcoins' allows for MultiPoolMiner to calculate and determine what is mined from all of the available coins (20xxx ports). Usage of the 'miningpoolhub' parameter is recommended as the pool have internal rules against switching before a block is found therefore prevents its users losing shares submitted due to early switching. A registered account is required when mining on MiningPoolHub (username must be provided using the -username command, see below).
	## Zpool http://www.zpool.ca/ (Bitcoin address must be provided using the -wallet command, see below)
	## Hash Refinery http://pool.hashrefinery.com (Bitcoin address must be provided using the -wallet command, see below)
	## Nicehash https://www.nicehash.com/ (Bitcoin address must be provided using the -wallet command, see below)
	## Ahashpool https://www.ahashpool.com/ (Bitcoin address must be provided using the -wallet command, see below)
	## Upcoming pool support for: BlockMunch (http://www.blockmunch.club/) | ItalYiiMP (http://www.italyiimp.com/) | UniMining (http://www.unimining.net)
	
	IMPORTANT: The specified pool here will be used as default (preferred) but this does not rule out other pools to be included. Selecting multiple pools is allowed and will be used on a failover basis OR if first specified pool does not support that algorithm/coin. See the -algorithm command below for further details and example.
	
-ExcludePoolName
	Same as the -poolname command but it is used to exclude unwanted mining pools (please see above).

-username 
	Your username you use to login to MiningPoolHub.

-workername
	To identify your mining rig.	

-wallet
	Your Bitcoin payout address. Required when mining on Zpool, Hash Refinery and Nicehash.
	
-SSL
	Specifying the -ssl command (without a boolean value of true or false) will restrict the miner application list to include only the miners that support secure connection.

-type [AMD,NVIDIA,CPU]
	Choose the relevant GPU(s) and/or CPU mining.

-algorithm
        Supported algorithms sorted by pool can be found at https://multipoolminer.io/algorithms.php
	The following algorithms are currently supported: 
	Bitcore, Blakecoin, Blake2s, BlakeVanilla, C11, CryptoNight, Ethash, X11, Decred, Equihash, Groestl, HMQ1725, JHA, Keccak, Lbry, Lyra2RE2, Lyra2z, MyriadGroestl, NeoScrypt, Nist5, Pascal, Polytimos, Quark, Qubit, Scrypt, SHA256, Sia, Sib, Skunk, Skein, Timetravel, Tribus, BlakeVanilla, Veltor, X11, X11evo, X17, Yescrypt
	Special parameters: 
	ethash2gb - can be profitable for older GPUs that have 2GB or less GDDR memory. It includes ethash coins that have a DAG file size of less than 2GB (and will be mined when most profitable). Ethereum and a few other coins have surpassed this size therefore cannot be mined with older cards.
	sianicehash and decrednicehash - if you want to include non-dual, non-Claymore Sia and Decred mining on Nicehash. NH created their own implementation of Sia and Decred mining protocol.
	siaclaymore - enable mining Sia as a secondary coin with Claymore Dual ethash miner on MiningPoolHub
	Note that the pool selected also needs to support the required algorithm(s) or your specified pool (-poolname) will be ignored when mining certain algorithms. The -algorithm command is higher in execution hierarchy and can override pool selection. This feature comes handy when you mine on Zpool but also want to mine ethash coins (which is not supported by Zpool). WARNING! If you add all algorithms listed above, you may find your earnings spread across 3 different pools regardless what pool(s) you specified with the -poolname command.
	
-ExcludeAlgorithm
	Same as the -algorithm command but it is used to exclude unwanted algorithms (please see above).
	
-currency [BTC,USD,EUR,GBP,ETH ...]
	Choose the default currency or currencies your profit stats will be shown in.

-interval
	MultiPoolMiner's update interval in seconds. This is a universal timer for running the entire script (downloading/processing APIs, calculation etc).  It also determines how long a benchmark is run for each miner file (miner/algorithm/coin). Default is 60.
	
-delay
	Specify the number of seconds required to pass before opening each miner. It is useful if cards are sensitive to switching and need some extra time to recover (eg. clear DAG files from memory)

-donate
	Donation of mining time in minutes per day to aaronsace. Default is 24, minimum is 10 minutes per day (less than 0.7% fee). The downloaded miner software can have their own donation system built in. Check the readme file of the respective miner used for more details.

-watchdog
        Include this command to enable the watchdog feature which detects and handles miner and other related failures.
	It works on a unified interval that is defaulted to 60 seconds. Watchdog timers expire if three of those intervals pass without being kicked. There are three stages as to what action is taken when watchdog timers expire and is determined by the number of related expired timers.
	- Stage 1: when 1 timer expires relating to one miner/algorithm combination, the one miner/algorithm combination is kicked
	- Stage 2: when 2 timers expire relating to one miner file, the one miner file is kicked
	- Stage 3: when 3 timers expire relating to one pool, the pool is kicked
	Watchdog timers reset after three times the number of seconds it takes to get to stage 3.
	
	
====================================================================
	
	
SAMPLE USAGE (check "start.bat" file in root folder):

setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "&.\multipoolminer.ps1 -wallet 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb -username aaronsace -workername multipoolminer -ssl -region europe -currency btc,usd,eur -type amd,nvidia,cpu -poolname miningpoolhub,miningpoolhubcoins,zpool,nicehash -algorithm cryptonight,decred,decrednicehash,ethash,ethash2gb,equihash,groestl,lbry,lyra2z,neoscrypt,pascal,sia,siaclaymore,sianicehash,sib -donate 10"


====================================================================


KNOWN ISSUES:

There are known issues with the following miners not submitting shares or show higher hashrate than what they actually do:
- CCminerLyraZ
- CCminerLyra2RE2
This is not a fault of MultiPoolMiner and nothing can be done on our end. Please raise an issue on their respective github pages. See FAQ#2 on how to exclude these if you wish to do so.


====================================================================


FREQUENTLY ASKED QUESTIONS:

Q1. How do I start using MultiPoolMiner?
A1. The 'start.bat' file is an example that shows how to run the script without prompting for a username. Amend it with your username/address/workername and other relevant details such as region. Ensure it is run as Administrator to prevent errors.

Q2. A miner crashes my computer or does not work correctly. I want to exclude it from mining/benchmarking. What should I do?
A2. Simply locate the configuration file for that particular miner in the /Miners folder and delete the file or exclude that algorithm entirely (see FAQ#4 below). These have either .txt or .ps1 file extensions. Please note that some of the miners have multiple config files and/or can mine multiple coins/algorithms. (Planned enhancement for V3)

Q3. Miner says CL device is missing (or not found). How do I resolve this issue?
A3. You most likely have NVIDIA cards in your rig. Open the start.bat in a text editor and look for ‘-type amd,nvidia,cpu’ and change it to ‘-type nvidia,cpu’. This will disable the AMD exclusive miners and save you plenty of time when benchmarking. You can also exclude the cpu option if you don’t want to mine with your processor.

Q4. I only want to mine certain algorithms even if they are not the most profitable. I want to exclude algorithms. How do I do that?
A4. Open the start.bat in a text editor and look for ‘-algorithm cryptonight,ethash,equihash,groestl,lyra2z,neoscrypt,pascal,sia’. Delete the algorithms you don't want to mine. This can save you some time when benchmarking. For a full list of supported algorithms, check the Algorithms.txt. You can include any of these or even all of them if you please but bear in mind this can result your earnings to be spread across many pools!

Q5. MultiPoolMiner is XX% more profitable. What does this mean?
A5. It is showing you the stat for MultiPoolMiner vs the one miner. It means that the calculated earnings of MultiPoolMiner switching to different algorithms would be that much more profitable than if it had just mined that one particular algorithm the whole time. The number is still only an estimate of your earnings on the pool and may not directly reflect what you actually get paid. On MiningPoolHub and other multiple algorithm pools, coins have fluctuating values and MultiPoolMiner switches to the one that is the most profitable at that time. Because each pool has different delays in exchange and payout, the amount you actually earn my be very different. If there is a significant difference in percentage, you might want to reset the profitability stats by running the ResetProfit.bat file. Your actual (but still estimated) earning is shown in the second row.

Q6. I want to re-run the benchmarks (changed OC settings, added new cards, etc.)
A6. Simply run 'ResetBenchmark.bat' This deletes all files in the /Stats folder. This will force MultiPoolMiner to run the benchmarks again. If you only want to re-run a single benchmark for a coin or algorithm, locate the appropriate stat file for that particular coin or algorithm and delete it. Please note some of the miners can do multiple algorithms therefore have multiple stat files for the same miner and some of them create multiple stat files for the different configuration files they use.

Q7. How long does benchmarking take to finish?
A7. This is greatly dependant on the amount of selected algorithms and the number of device types chosen in the start.bat file. By default, each benchmark takes one minute. You can speed up benchmarking significantly by omitting unused device types. For example if you have a rig with AMD cards, you can tell MPM not to even launch the NVIDIA or CPU specific miner applications by removing these after the -type parameter in the start.bat file.

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
A14. Yes, advanced users can edit the currency settings in each pool file by amending the password field (c=BTC), however, this is not recommended as your payout will become uncertain as all other payout currencies are internally exchanged therefore you may end up losing your earnings due to pool never having enough coins to pay you!

Q15. How do I customise miners to better work with my cards?
A15. Some cards may require special parameters to be used in order to make them (more) stable, such as setting intensity for specific miners/algos/GPUs. This can be done by heading to the /Miners folder and editing the relevant miner files. For example, for CcminerTpruvot.ps1 you can replace
"x17" = "" # X17
with:
"x17" = " -i 20" # X17 (mind the spaces! " -i 20")
to add intensity setting for that specific algorithm while used in conjuction with tpruvot's ccminer fork. This will result this specific miner on that specific algorithm will use the intensity setting of 20 which may help if you are experiencing driver crashes when using certain cards. Please search relevant forums for correct and recommended settings before changing anything!

Q16. I am getting: ErrorCode error = method(handle, name, <IntPtr>Marshal.SizeOf<T>(),h.AddrOfPinnedObject(), out size); 
A16. Microsoft .NET Framework 4.5.1 or later is required for MultiPoolMiner to function properly. Please update from here: https://www.microsoft.com/en-us/download/details.aspx?id=40773

Q17. Is there an option to split earnings? I want to mine 80% of the time to wallet A and 20% of the time to wallet B.
A17. This feature is not implemented, however, there are external services you can use to achieve the same such as https://coinsplit.io/

Q18. How to change fault tolerance limit to a higher percentage?
A18. Fault tolerance limit was implemented to detect unwanted negative or positive spikes in your hashrate caused by faulty miners or GPUs and prevent these statistics to be recorded to keep your benchmark data preserved in these unfortunate events. You should not feel the need to change this but first try to resolve the issues with your miners and/or devices. That said, if you are absolutely certain you want to change this, you can do so by amending the following line in Include.ps1:
    [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, 0.1), 0.9)
    TO:
    0.3
This will change the fault tolerance limit to 30%.

Q19. MultiPoolMiner is not mining the most profitable algorithm. Why?
A19. MPM version 2.7 introduced a smarter spike resistance for both of your hashrate and coin difficulty/price ratio. This feature will detect and handle mining accordingly to prevent you losing time and profit. The usual case is, if an algorithm's price fluctuates a lot, then the short time profit might appear to be higher, but by the time you have mined it for a period of time, the coins will be exchanged for a much lower price and your mining will be less profitable. This is due to the PPLNS(+) nature implemented in the pools. To mitigate this effect MPM uses an 24h mean price (if provided by the pool) when determininig the most profitable algo. [#712] [#713] [query re NH to be resolved/omitted]

Q20. I am getting the following error: "NetFirewallRule - Access denied"
A20. You cannot put MultiPoolMiner inside directorires such as Program Files. Extract it to a non-restricted or user-created folder such as Desktop, Downloads, Documents, C:\MPM\ etc.

Q21. My antivirus says the .zip package contains a virus or MultiPoolMiner tries to download viruses. What should I do?
A21. MultiPoolMiner is open-source and used by many users/rigs. It also downloads miners from github releases that are open-sourced projects. That means the code is readable and you can see for yourself it does not contain any viruses. Your antivirus generates false positives as the miner software used by MultiPoolMiner are often included in malicious programs to create botnets for someone who wants to earn a quick buck. There are other closed-source miner program included in the package such as the Claymore miners. These come from legendary ranked or trusted/respected members of the bitcointalk community and used by a large number of users/rigs worldwide. You can exlude these miners if you wish by following the instructions in FAQ#2 and delete their software from your system. 
