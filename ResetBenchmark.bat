@echo off
set /p benchreset= This process will remove all benchmarking data. Are you sure you want to continue? [Y/N] 
IF /I "%benchreset%"=="Y" (
	if exist "Stats\*_HashRate.txt" del "Stats\*_HashRate.txt"
	ECHO Success. You need to rebenchmark all required algorithms to continue using MultiPoolMiner.
	PAUSE
)
