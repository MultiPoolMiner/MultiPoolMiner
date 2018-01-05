export GPU_FORCE_64BIT_PTR=1
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECT=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100

pwsh -noexit -executionpolicy bypass -file ./MultiPoolMiner.ps1 "&-wallet 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb -username aaronsace -workername multipoolminer -region us -currency btc,usd -type nvidia,cpu -poolname miningpoolhub,miningpoolhubcoins,zpool -algorithm cryptonight,decred,decrednicehash,ethash,ethash2gb,equihash,groestl,lbry,lyra2z,neoscrypt,pascal,sia,siaclaymore,sianicehash,sib -donate 10 -watchdog"