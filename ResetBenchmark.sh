echo 'This process will remove all benchmarking data. Are you sure you want to continue? [Y/N]'
read ans
if [ "$ans" == "Y" ]; then
    [ -e Stats/*_HashRate.txt ] && rm Stats/*_HashRate.txt
    echo 'Success. You need to rebenchmark all required algorithms to continue using MultiPoolMiner.'
fi