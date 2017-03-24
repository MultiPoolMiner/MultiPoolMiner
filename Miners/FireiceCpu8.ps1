$Threads = 8
$Path_Threads = ".\Bin\Cryptonight-CPU$Threads\xmr-stak-cpu.exe"

$Path = ".\Bin\Cryptonight-CPU\xmr-stak-cpu.exe"
$Uri = 'https://github.com/fireice-uk/xmr-stak-cpu/releases/download/v1.1.0-1.3.1/xmr-stak-cpu-win64.zip'

if((Test-Path $Path) -eq $false)
{
    $FolderName_Old = ([IO.FileInfo](Split-Path $Path -Leaf)).BaseName
    $FolderName_New = Split-Path (Split-Path $Path) -Leaf
    $FileName = "$FolderName_New$(([IO.FileInfo](Split-Path $Uri -Leaf)).Extension)"

    if(Test-Path $FileName){Remove-Item $FileName}
    if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_New"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_New" -Recurse}
    if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_Old"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" -Recurse}

    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    Start-Process "7z" "x $FileName -o$(Split-Path (Split-Path $Path))\$FolderName_Old -y -spe" -Wait
    Rename-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" "$FolderName_New"
}

if((Test-Path $Path_Threads) -eq $false)
{
    Copy-Item (Split-Path $Path) (Split-Path $Path_Threads) -Recurse
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Port = 3334

(Get-Content "$(Split-Path $Path_Threads)\config.txt") `
-replace """pool_address"" : ""[^""]*"",", """pool_address"" : ""$($Pools.Cryptonight.Host):$($Pools.Cryptonight.Port)""," `
-replace """wallet_address"" : ""[^""]*"",", """wallet_address"" : ""$($Pools.Cryptonight.User)""," `
-replace """pool_password"" : ""[^""]*"",", """pool_password"" : ""x""," `
-replace """httpd_port"" : [^""]*,", """httpd_port"" : $Port," `
-replace """cpu_thread_num"" : [^""]*,", """cpu_thread_num"" : $Threads," | `
Set-Content "$(Split-Path $Path_Threads)\config.txt"

[PSCustomObject]@{
    Type = 'CPU'
    Path = $Path_Threads
    Arguments = ''
    HashRates = [PSCustomObject]@{Cryptonight = '$($Stats.' + $Name + '_Cryptonight_HashRate.Week)'}
    API = 'FireIce'
    Port = $Port
    Wrap = $false
    URI = $Uri
}