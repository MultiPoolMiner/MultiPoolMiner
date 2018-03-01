cd /d %~dp0

setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

set "command=& .\multipoolminer.ps1 -wallet 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb -username aaronsace -workername multipoolminer -region europe -currency btc,usd,eur -type amd,nvidia,cpu -poolname miningpoolhubcoins,zpool,nicehash -algorithm blake2s,cryptonight,decrednicehash,ethash,ethash2gb,equihash,groestl,keccak,lbry,lyra2re2,lyra2z,neoscrypt,pascal,sib,skunk -donate 24 -watchdog -minerstatusurl https://multipoolminer.io/monitor/miner.php -switchingprevention 2"

REM start powershell -noexit -executionpolicy bypass -command "& .\reader.ps1 -log 'MultiPoolMiner_\d\d\d\d-\d\d-\d\d\.txt' -sort '^[^_]*_' -quickstart"
powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

pause
