echo 'This process will delete all unnecessary log files created by the miners and MultiPoolMiner to free up space. Are you sure you want to continue? [Y/N]'
read ans
if [ "$ans" == "Y" ]; then
    [ -e Bin/Cryptonight-Claymore/*_log.txt ] && rm Bin/Cryptonight-Claymore/*_log.txt
    [ -e Bin/Equihash-Claymore/*_log.txt ] && rm Bin/Equihash-Claymore/*_log.txt
    [ -e Bin/Ethash-Claymore/*_log.txt ] && rm Bin/Ethash-Claymore/*_log.txt
    echo 'All existing log files have been successfully deleted.'
fi