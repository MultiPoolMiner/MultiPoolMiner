$Path = '.\Bin\CPU-JayDDee\cpuminer-sse42.exe'
$Uri = 'https://github.com/JayDDee/cpuminer-opt/releases/download/v3.6.3/cpuminer-opt-3.6.3-windows.zip'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Lyra2z = 'lyra2z' #not supported
    #Equihash = 'equihash' #not supported
    Cryptonight = 'cryptonight'
    #Ethash = 'ethash' #not supported
    #Sia = 'sia' #not supported
    #Yescrypt = 'yescrypt' #use TpruvoT
    #BlakeVanilla = 'vanilla' #use TpruvoT
    #Lyra2RE2 = 'lyra2v2' #use TpruvoT
    #Skein = 'skein' #use TpruvoT
    #Qubit = 'qubit' #use TpruvoT
    #NeoScrypt = 'neoscrypt' #use TpruvoT
    #X11 = 'x11' #use TpruvoT
    #MyriadGroestl = 'myr-gr' #use TpruvoT
    #Groestl = 'groestl' #use TpruvoT
    #Keccak = 'keccak' #use TpruvoT
    #Scrypt = 'scrypt' #use TpruvoT
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