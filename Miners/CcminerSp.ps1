$Path = '.\Bin\NVIDIA-SP\ccminer.exe'
$Uri = "https://github.com/sp-hash/ccminer/releases/download/1.5.81/release81.7z"

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    #Equihash = 'equihash' #not supported
    #Cryptonight = 'cryptonight' #not supported
    #Ethash = 'ethash' #not supported
    #Sia = 'sia' #use TpruvoT
    #Yescrypt = 'yescrypt' #use TpruvoT
    #BlakeVanilla = 'vanilla' #use TpruvoT
    #Lyra2RE2 = 'lyra2v2' #use TpruvoT
    Skein = 'skein'
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
    Skein = ' -i 27'
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
        Arguments = -Join ('-b 127.0.0.1:4068 -a ', $Algorithms.$_, ' -o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p x', $Optimizations.$_)
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Day)')}
        API = 'Ccminer'
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}