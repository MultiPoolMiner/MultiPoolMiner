@echo off
set /p statreset= This process will remove all accumulated coin data and reset your profit statistics. Are you sure you want to continue? [Y/N] 
IF /I "%statreset%"=="Y" (
	if exist "Stats\*Profit.txt" del "Stats\*Profit.txt"
	ECHO Your stats have been successfully reset.
	PAUSE
)
