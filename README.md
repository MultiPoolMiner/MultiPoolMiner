# MultiPoolMiner - developed by aaronsace
Monitors crypto mining pools in real-time in order to find the most profitable for your machine. Controls any miner that is available via command line. Supports benchmarking and multi-chip support (AMD, NVIDIA and CPU).

Bitcoin Donations: **1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH**
Integrated donation option is available.

Available optional settings:
-Interval [Seconds]
-Location [Europe/US/Asia]
-SSL
-Type [i.e. AMD,NVIDIA,CPU]
-Algorithm [i.e. Cryptonight,Ethash,Equihash,Lyra2z]
-Currency [i.e. BTC,USD]
-Donate [Minutes per Day]

Just right click and run the script then enter your MiningPoolHub username once prompted; that’s it.
Look out for security warnings and firewall exceptions when prompted during benchmark.

The 'start.bat' file is an example that shows how to run the script without prompting for a username.
Advanced users can add more miners in the ‘miners’ folder either as JSON or PS1.

Please see the FAQ section on the bottom of this page before submitting bugs and feature requests on Github. https://github.com/aaronsace/MultiPoolMiner/issues
Logs and Stats are produced in text format; use them when submitting issues.

Any bitcoin donations are greatly appreciated: 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH

**Notes**
- It is not recommended but to upgrade from a previous version of MultiPoolMiner, you may simply copy the 'stats' folder.
- If you have Windows 7, please update PowerShell: 
https://www.microsoft.com/en-us/download/details.aspx?id=50395
- CCMiner may need 'MSVCR120.dll' if you don't already have it: 
https://www.microsoft.com/en-gb/download/details.aspx?id=40784
- CCMiner may need 'VCRUNTIME140.DLL' if you don't already have it: 
https://www.microsoft.com/en-us/download/details.aspx?id=48145
- You may need 'excavator.exe' if you don't already have it: 
https://github.com/nicehash/excavator/releases


Frequently Asked Questions (v1.8):

Q1. A miner crashes my computer or does not work correctly. I want to exclude it from mining/benchmarking. What should I do?
A1. Simply locate the configuration file for that particular miner in the /Miners folder and delete the file or exclude that algorithm entirely (see Q3 below). These have either .txt or .ps1 file extensions. Please note that some of the miners have multiple config files and/or can mine multiple coins/algorithms.

Q2. Miner says CL device is missing (or not found). How do I resolve this issue?
A2. You most likely have NVIDIA cards in your rig. Open the start.bat in a text editor and look for ‘-type amd,nvidia,cpu’ and change it to ‘-type nvidia,cpu’. This will disable the AMD exclusive miners and save you plenty of time when benchmarking. You can also exclude the cpu option if you don’t want to mine with your processor.

Q3. I only want to mine certain algorithms even if they are not the most profitable. I want to exclude algorithms. How do I do that?
A3. Open the start.bat in a text editor and look for ‘-algorithm cryptonight,ethash,equihash,groestl,lyra2z,neoscrypt,pascal,sia’. Delete the algorithms you don't want to mine. This can save you some time when benchmarking. For a full list of supported algorithms, check the Algorithms.txt. You can include any of these or even all of them if you please.

Q4. MultiPoolMiner is XX% more profitable than conventional mining. What does this mean?
A4. It is showing you the stat for MultiPoolMiner vs the one miner. It means that the calculated earnings of MultiPoolMiner switching to different algorithms would be that much more profitable than if it had just mined that one particular algorithm the whole time. The number is still only an estimate of your earnings on the pool and may not directly reflect what you actually get paid. On MiningPoolHub and other multiple algorithm pools, coins have fluctuating values and MultiPoolMiner switches to the one that is the most profitable at that time. Because each pool has different delays in exchange and payout, the amount you actually earn my be very different. If there is a significant difference in percentage, you might want to reset the profitability stats by deleting Profit.txt in the /Stats folder. Your actual (but still estimated) earning is shown in the second row.

Q5. I want to re-run the benchmarks (changed OC settings, added new cards, etc.)
A5. Navigate to the /Stats folder and delete all files in that folder. This will force MultiPoolMiner to run the benchmarks again. If you only want to re-run a single benchmark for a coin or algorithm, locate the appropriate stat file for that particular coin or algorithm and delete it. Please note some of the miners can do multiple algorithms therefore have multiple stat files for the same miner and some of them create multiple stat files for the different configuration files they use.

Q6. How long does benchmarking take to finish?
A6. This is greatly dependant on the amount of selected algorithms and the number of device types chosen in the start.bat file. By default, each benchmark takes one minute. You can speed up benchmarking significantly by omitting unused device types. For example if you have a rig with AMD cards, you can tell MPM not to even launch the NVIDIA or CPU specific miner applications by removing these after the -type parameter in the start.bat file.

Q7. Is it possible to choose how many GPUs we want to allocate to mining or restrict mining on certain GPUs?
A7. This feature will possibly be implemented in the future but not yet supported by MultiPoolMiner.

Q8. MultiPoolMiner says it cannot find excavator.exe
A8. Excavator is developed by Nicehash and their EULA does not permit redistribution of their software which means you need to download Excavator manually from https://github.com/nicehash/excavator/releases and place it in /Bin/Excavator/ (create the folder if does not exist). This is the permitted use of Excavator.

