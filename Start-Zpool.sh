export GPU_FORCE_64BIT_PTR=1
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100

pwsh -noexit -executionpolicy bypass -file ./MultiPoolMiner.ps1 "&-wallet 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb -username aaronsace -workername multipoolminer -region europe -currency btc,usd,eur -type amd,nvidia,cpu -poolname zpool -algorithm decred,equihash,groestl,lbry,neoscrypt,sib -donate 24 -watchdog"