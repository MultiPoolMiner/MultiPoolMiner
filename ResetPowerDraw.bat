@echo off
cd /d %~dp0
set /p statreset= This process will remove all accumulated power data and reset your power statistics. Are you sure you want to continue? [Y/N]  
IF /I "%statreset%"=="Y" (
	if exist "Stats\*PowerDraw.txt" del "Stats\*PowerDraw.txt"
	ECHO Your stats have been successfully reset.
	PAUSE
)