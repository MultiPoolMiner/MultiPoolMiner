$Path = '.\Bin\AMD-GenesisMining\sgminer.exe'
$Uri = "https://github.com/genesismining/sgminer-gm/releases/download/5.5.5/sgminer-gm.zip"
$Uri_SubFolder = $true

if((Test-Path $Path) -eq $false)
{
    $FolderName_Old = if($Uri_SubFolder){([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}else{""}
    $FolderName_New = Split-Path (Split-Path $Path) -Leaf
    $FileName = "$FolderName_New$(([IO.FileInfo](Split-Path $Uri -Leaf)).Extension)"

    try
    {
        if(Test-Path $FileName){Remove-Item $FileName}
        if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_New"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_New" -Recurse}
        if($FolderName_Old -ne ""){if(Test-Path "$(Split-Path (Split-Path $Path))\$FolderName_Old"){Remove-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" -Recurse}}
        Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
        if($FolderName_Old -ne ""){Start-Process "7za" "x $FileName -o$(Split-Path (Split-Path $Path)) -y" -Wait}else{Start-Process "7za" "x $FileName -o$(Split-Path $Path) -y" -Wait}
        if($FolderName_Old -ne ""){Rename-Item "$(Split-Path (Split-Path $Path))\$FolderName_Old" "$FolderName_New"}
    }
    catch
    {
        return
    }
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Equihash = 'equihash'
    Cryptonight = 'cryptonight'
    Ethash = 'ethash'
    Sia = 'sia'
    Yescrypt = 'yescrypt'
    BlakeVanilla = 'vanilla'
    Lyra2RE2 = 'lyra2rev2'
    Skein = 'skeincoin'
    Qubit = 'qubitcoin'
    NeoScrypt = 'neoscrypt'
    X11 = 'darkcoin-mod'
    MyriadGroestl = 'myriadcoin-groestl'
    Groestl = 'groestlcoin'
    Keccak = 'maxcoin'
    Scrypt = 'zuikkis'
}

$Optimizations = [PSCustomObject]@{
    Equihash = ' --gpu-threads 2 --worksize 256 -no-adl'
    Cryptonight = ' --gpu-threads 1 --worksize 8 --rawintensity 896 -no-adl'
    Ethash = ' --gpu-threads 1 --worksize 192 --xintensity 1024 -no-adl'
    Sia = ' -no-adl'
    Yescrypt = ' --worksize 4 --rawintensity 256 -no-adl'
    BlakeVanilla = ' --intensity d -no-adl'
    Lyra2RE2 = ' --gpu-threads 2 --worksize 128 --intensity d -no-adl'
    Skein = ' --gpu-threads 2 --intensity d -no-adl'
    Qubit = ' --gpu-threads 2 --worksize 128 --intensity d -no-adl'
    NeoScrypt = ' -no-adl -no-adl'
    X11 = ' --gpu-threads 2 --worksize 128 --intensity d -no-adl'
    MyriadGroestl = ' --gpu-threads 2 --worksize 64 --intensity d -no-adl'
    Groestl = ' --gpu-threads 2 --worksize 128 --intensity d -no-adl'
    Keccak = ' -no-adl'
    Scrypt = ' -no-adl'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'AMD'
        Path = $Path
        Arguments = -Join ('--api-listen -k ', $Algorithms.$_, ' -o $($Pools.', $_, '.Protocol)://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x', $Optimizations.$_)
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Xgminer'
        Port = 4028
        Wrap = $false
    }
}