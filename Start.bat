cd /d %~dp0

setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

set "command=& .\multipoolminer.ps1"

#pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
powershell -version 5.1 -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"
#msiexec -i https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-rc.2/PowerShell-6.0.0-rc.2-win-x64.msi -qb!
#pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

pause