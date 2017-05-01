$Path = '.\Bin\NVIDIA-TPruvot\ccminer-x64.exe'
$Uri = 'https://github.com/tpruvot/ccminer/releases/download/2.0-rc3/ccminer-2.0-rc3-cuda-7.5.7z'

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Algorithms = [PSCustomObject]@{
    Lyra2z = 'lyra2z'
    #Equihash = 'equihash' #not supported
    Cryptonight = 'cryptonight'
    #Ethash = 'ethash' #not supported
    Sia = 'sia'
    Yescrypt = 'yescrypt'
    BlakeVanilla = 'vanilla'
	Blake2s = 'blake2s'
    Lyra2RE2 = 'lyra2v2'
	Lyra2v2 = 'lyra2v2'
    #Skein = 'skein'
    Qubit = 'qubit'
    NeoScrypt = 'neoscrypt'
	Nist5 = 'nist5'
    X11 = 'x11'
	X11evo = 'x11evo'
	X17 = 'x17'
    MyriadGroestl = 'myr-gr'
    #Groestl = 'groestl'
    Keccak = 'keccak'
    Scrypt = 'scrypt'
	Lbry = 'lbry'
	Decred = 'decred'
    Sib = 'sib'
	Timetravel = 'timetravel'
}

$Optimizations = [PSCustomObject]@{
    Lyra2z = ''
    Equihash = ''
    Cryptonight = ''
    Ethash = ''
    Sia = ''
    Yescrypt = ''
    BlakeVanilla = ''
	Blake2s = ''
    Lyra2RE2 = ''
	Lyra2v2 = ''
    Skein = ''
    Qubit = ''
    NeoScrypt = ''
	Nist5 = ''
    X11 = ''
	X11evo = ''
	X17 = ''
    MyriadGroestl = ''
    Groestl = ''
    Keccak = ''
    Scrypt = ''
	Lbry = ''
	Decred = ''
    Sib = ''
	Timetravel = ''
}

$Algorithms | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = 'NVIDIA'
        Path = $Path
        Arguments = -Join ('-a ', $Algorithms.$_, ' -o stratum+tcp://$($Pools.', $_, '.Host):$($Pools.', $_, '.Port) -u $($Pools.', $_, '.User) -p $($Pools.', $_, '.Pass)', $Optimizations.$_)
        HashRates = [PSCustomObject]@{$_ = -Join ('$($Stats.', $Name, '_', $_, '_HashRate.Week)')}
        API = 'Ccminer'
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}