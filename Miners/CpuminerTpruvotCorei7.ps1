$Path = '.\Bin\CPU-TPruvot\cpuminer-gw64-corei7.exe'
$Uri = 'https://github.com/tpruvot/cpuminer-multi/releases/download/v1.3.1-multi/cpuminer-multi-rel1.3.1-x64.zip'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    #Lyra2z = 'lyra2z' #not supported
    #Equihash = 'equihash' #not supported
    Cryptonight = 'cryptonight'
    #Ethash = 'ethash' #not supported
    Sia = 'sia'
    Yescrypt = 'yescrypt'
    BlakeVanilla = 'vanilla'
    Lyra2RE2 = 'lyra2v2'
    Skein = 'skein'
    Qubit = 'qubit'
    NeoScrypt = 'neoscrypt'
    X11 = 'x11'
    MyriadGroestl = 'myr-gr'
    Groestl = 'groestl'
    Keccak = 'keccak'
    Scrypt = 'scrypt'
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'CPU'
        Path = $Path
        Arguments = -Join ('-a ', $Algorithms.$_, ' -o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p $($Pools.', $_, '.Pass)')
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Week)')}
        API = 'Ccminer'
        Port = 4048
        Wrap = $false
        URI = $Uri
    }
}