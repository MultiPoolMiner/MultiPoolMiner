cd %~dp0

setlocal enabledelayedexpansion
set wallet=1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb
set username=aaronsace
set workername=multipoolminer
set region=europe
set currency=btc,usd,eur
set type=amd,nvidia,cpu
set poolname=miningpoolhub,miningpoolhubcoins,zpool,nicehash
set algorithm=equihash,skunk,decred,sia,lbry,pascal,ethash,siaclaymore,keccak,lyra2re2,hsr,phi,jha,timetravel,tribus,x11evo,polytimos,x17,c11,skein,sib,nist5,myr-gr,blakecoin,blake2s,veltor,cryptonight,groestl,lyra2z,neoscrypt,yescrypt,xevan,vanilla,keccakc,jha,blakevanilla,blakevanilla
set donate=24

setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

set "command=& .\multipoolminer.ps1 -wallet %wallet% -username %username% -workername %workername% -region %region% -currency %currency% -type %type% -poolname %poolname% -algorithm %algorithm% -donate %donate% -watchdog"

pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
msiexec -i https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-rc.2/PowerShell-6.0.0-rc.2-win-x64.msi -qb!
pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

pause
