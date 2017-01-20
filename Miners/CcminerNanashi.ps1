$Path = '.\Bin\NVIDIA-Nanashi\ccminer.exe'
$Uri = "https://github.com/nicehash/ccminer-nanashi/releases/download/1.7.6-r6/ccminer.zip"
$Uri_SubFolder = $false

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
    #Equihash = 'equihash' #not supported
    #Cryptonight = 'cryptonight' #not supported
    #Ethash = 'ethash' #not supported
    #Sia = 'sia' #use TpruvoT
    #Yescrypt = 'yescrypt' #use TpruvoT
    #BlakeVanilla = 'vanilla' #use TpruvoT
    Lyra2RE2 = 'lyra2v2'
    #Skein = 'skein' #use TpruvoT
    #Qubit = 'qubit' #use TpruvoT
    #NeoScrypt = 'neoscrypt' #use TpruvoT
    #X11 = 'x11' #use TpruvoT
    #MyriadGroestl = 'myr-gr' #use TpruvoT
    #Groestl = 'groestl' #use TpruvoT
    #Keccak = 'keccak' #use TpruvoT
    #Scrypt = 'scrypt' #use TpruvoT
}

$Optimizations = [PSCustomObject]@{
    Equihash = ''
    Cryptonight = ''
    Ethash = ''
    Sia = ''
    Yescrypt = ''
    BlakeVanilla = ''
    Lyra2RE2 = ''
    Skein = ''
    Qubit = ''
    NeoScrypt = ''
    X11 = ''
    MyriadGroestl = ''
    Groestl = ''
    Keccak = ''
    Scrypt = ''
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'NVIDIA'
        Path = $Path
        Arguments = -Join ('-a ', $Algorithms.$_, ' -o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x', $Optimizations.$_)
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Ccminer'
        Port = 4068
        Wrap = $false
    }
}