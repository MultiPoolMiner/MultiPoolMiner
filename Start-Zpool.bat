@cd /d %~dp0

@if not "%GPU_FORCE_64BIT_PTR%"=="1" (setx GPU_FORCE_64BIT_PTR 1) > nul
@if not "%GPU_MAX_HEAP_SIZE%"=="100" (setx GPU_MAX_HEAP_SIZE 100) > nul
@if not "%GPU_USE_SYNC_OBJECTS%"=="1" (setx GPU_USE_SYNC_OBJECTS 1) > nul
@if not "%GPU_MAX_ALLOC_PERCENT%"=="100" (setx GPU_MAX_ALLOC_PERCENT 100) > nul
@if not "%GPU_SINGLE_ALLOC_PERCENT%"=="100" (setx GPU_SINGLE_ALLOC_PERCENT 100) > nul
@if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

@set "command=& .\multipoolminer.ps1 -Wallet 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb -UserName aaronsace -WorkerName multipoolminer -Region europe -Currency btc,usd,eur -DeviceName amd,nvidia,cpu -PoolName zpool -algorithm blake2s,equihash,hex,keccak,lbry,lyra2z,m7m,neoscrypt,sib,skein,skunk,x16r,x16s,x17,x22i -Donate 24 -Watchdog -MinerStatusURL https://multipoolminer.io/monitor/miner.php -SwitchingPrevention 2 -UseFastestMinerPerAlgoOnly"

start /min pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log '.*\\MultiPoolMiner_\d\d\d\d-\d\d-\d\d.*\.txt$' -sort '^[^_]*_' -QuickStart"

pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

pause
