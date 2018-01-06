@echo off
cd /d %~dp0
ECHO Deleting benchmark data for updated miners

if exist "Stats\CcminerKlaust_*_HashRate.txt" del "Stats\CcminerKlaust_*_HashRate.txt"
if exist "Stats\CcminerLyra2z_*_HashRate.txt" del "Stats\CcminerLyra2z_*_HashRate.txt"
if exist "Stats\SgminerLyra2z_*_HashRate.txt" del "Stats\SgminerLyra2z_*_HashRate.txt"
if exist "Stats\ReorderAMD_*_HashRate.txt" del "Stats\Reorder_*_HashRate.txt"
if exist "Stats\ReorderNVIDIA_*_HashRate.txt" del "Stats\ReorderNVIDIA_*_HashRate.txt"
if exist "Stats\CcminerTpruvot_*_HashRate.txt" del "Stats\CcminerTpruvot_*_HashRate.txt"

ECHO You need to rebenchmark some algorithms.
PAUSE
