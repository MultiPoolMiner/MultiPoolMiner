echo 'This process will remove all accumulated coin data and reset your profit statistics. Are you sure you want to continue? [Y/N]'
read ans
if [ "$ans" == "Y" ]; then
    [ -e Stats/*Profit.txt ] && rm Stats/*Profit.txt
    echo 'Your stats have been successfully reset.'
fi