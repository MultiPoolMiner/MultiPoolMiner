@echo off
cd /d %~dp0
set /p powerusagereset= This process will remove all power usage data. Are you sure you want to continue? [Y/N] 
IF /I "%powerusagereset= %"=="Y" (
	if exist "Stats\*_HashRate.txt" del "Stats\*_PowerUsage.txt"
	ECHO Success. You need to measure the power consmuption for all required miners & algorithms to continue using MultiPoolMiner.
	PAUSE
)
