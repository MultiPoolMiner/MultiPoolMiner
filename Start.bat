setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "&.\multipoolminer.ps1 -username aaronsace -workername multipoolminer -interval 60 -location europe -ssl -type amd,nvidia,cpu -algorithm cryptonight,ethash,equihash,groestl,lyra2z,neoscrypt,pascal,sia -poolname miningpoolhub -currency btc,usd -donate 10"
