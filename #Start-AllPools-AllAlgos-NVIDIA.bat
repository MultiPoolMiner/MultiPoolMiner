cd /d %~dp0

setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

set "command=& .\multipoolminer.ps1 -wallet 1NVxfNNmrdQHzW1SuP2xyF2Fy39KWWMN7b -username nujan -workername %computername% -region us -currency btc,usd -type nvidia -donate 0 -excludealgorithm sha256,blake256,blakevanilla,decred,decrednicehash,sia,pascal,lbry,scrypt,x11,x13,x14,x15,quark,qubit,sib,nist5,myriadgroestl,blakecoin,cryptonight,groestl -minerstatusurl https://multipoolminer.io/monitor/miner.php -MinerStatusKey 30b122dd-1579-446f-a542-dbdc24d8066a -switchingprevention 1"

start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log 'MultiPoolMiner_\d\d\d\d-\d\d-\d\d\.txt' -sort '^[^_]*_' -quickstart"

pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
powershell -version 5.0 -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
msiexec -i https://github.com/PowerShell/PowerShell/releases/download/v6.0.2/PowerShell-6.0.2-win-x64.msi -qb!
pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

pause
