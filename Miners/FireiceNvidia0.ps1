$ThreadIndex = 0
$Path_Threads = ".\Bin\Cryptonight-NVIDIA$ThreadIndex\xmr-stak-nvidia.exe"

$Path = ".\Bin\Cryptonight-NVIDIA\xmr-stak-nvidia.exe"
$Uri = 'https://github.com/fireice-uk/xmr-stak-nvidia/releases/download/v1.1.1-1.4.0/xmr-stak-nvidia.zip'

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

$Port = 3335+($ThreadIndex*10000)

$Config = "{$((Get-Content "$(Split-Path $Path_Threads)\config.txt"))}" -replace "/\*(.|[\r\n])*?\*/" -replace ",(|[ \t\r\n])+}","}" -replace ",(|[ \t\r\n])+\]","]" ` | ConvertFrom-Json
$Config.pool_address = "$($Pools.Cryptonight.Host):$($Pools.Cryptonight.Port)"
$Config.wallet_address = "$($Pools.Cryptonight.User)"
$Config.pool_password = "x"
$Config.httpd_port = $Port
$Config.gpu_threads_conf = @(@{index = $ThreadIndex; threads = 17; blocks = 60; bfactor = 0; bsleep =  0; affine_to_cpu = $true})
($Config | ConvertTo-Json) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path_Threads)\config.txt"

[PSCustomObject]@{
    Type = 'NVIDIA'
    Path = $Path_Threads
    Arguments = ''
    HashRates = [PSCustomObject]@{Cryptonight = '$($Stats.' + $Name + '_Cryptonight_HashRate.Week)'}
    API = 'FireIce'
    Port = $Port
    Wrap = $false
    URI = $Uri
    Index = $ThreadIndex
}