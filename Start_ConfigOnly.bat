@echo off
cd /d %~dp0

rem ON MINING RIGS SET MININGRIG=TRUE
SET MININGRIG=FALSE

if not "%GPU_FORCE_64BIT_PTR%"=="1" (setx GPU_FORCE_64BIT_PTR 1) > nul
if not "%GPU_MAX_HEAP_SIZE%"=="100" (setx GPU_MAX_HEAP_SIZE 100) > nul
if not "%GPU_USE_SYNC_OBJECTS%"=="1" (setx GPU_USE_SYNC_OBJECTS 1) > nul
if not "%GPU_MAX_ALLOC_PERCENT%"=="100" (setx GPU_MAX_ALLOC_PERCENT 100) > nul
if not "%GPU_SINGLE_ALLOC_PERCENT%"=="100" (setx GPU_SINGLE_ALLOC_PERCENT 100) > nul
if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

set "command=& .\multipoolminer.ps1"

if exist "~*.dll" del "~*.dll" > nul 2>&1

if /I "%MININGRIG%" EQU "TRUE" goto MINING

rem Launch web dashboard
set "command=%command% -Dashboard"

if exist ".\SnakeTail.exe" goto SNAKETAIL

start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log 'MultiPoolMiner_\d\d\d\d-\d\d-\d\d\.txt' -sort '^[^_]*_' -quickstart"
goto MINING

:SNAKETAIL
tasklist /fi "WINDOWTITLE eq SnakeTail - MPM_SnakeTail_LogReader*" /fo TABLE 2>nul | find /I /N "SnakeTail.exe" > nul 2>&1
if "%ERRORLEVEL%"=="1" start /min .\SnakeTail.exe .\MPM_SnakeTail_LogReader.xml

:MINING
pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

echo Powershell 6 or later is required. Cannot continue.
pause