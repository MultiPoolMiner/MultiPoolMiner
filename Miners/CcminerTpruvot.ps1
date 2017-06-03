$Path = '.\Bin\NVIDIA-TPruvot\ccminer-x64.exe'
$Uri = 'https://github.com/tpruvot/ccminer/releases/download/v2.0-tpruvot/ccminer-2.0-release-x64-cuda-8.0.7z'

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
	Bitcore = 'bitcore'
	hmq1725 = 'hmq1725'
	Blakecoin = 'blakecoin'
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
	Bitcore = ''
	hmq1725 = ''
	Blakecoin = ''
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