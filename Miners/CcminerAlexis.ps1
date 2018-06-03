using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Alexis78hsr\ccminer.exe"
$HashSHA256 = "B0222106230616A31A93811640E8488BDCDA0FBF9EE2C5AD7EB1B3F4E4421884"
$Uri = "https://github.com/nemosminer/ccminerAlexis78/releases/download/Alexis78-v1.2/ccminerAlexis78v1.2x32.7z"

$Commands = [PSCustomObject]@{
    ### SUPPORTED ALGORITHMS - BEST PERFORMING MINER AS OF 03/06/2018
    "blake2s" = "" #Blake2s XVG
    "c11" = " -i 21" #X11evo; fix for default intensity
    "keccakc" = "" #keccakc
    "lyra2v2" = "" #lyra2v2
    "skein" = "" #Skein
    "x11evo" = " -N 1 -i 21" #X11evo; fix for default intensity, N samples for hashrate

    ### SUPPORTED ALGORITHMS - BEAT MY ANOTHER MINER AS OF 03/06/2018
    #"hsr" = "" #HSR, HShare
    #"keccak" = "" #Keccak SHA3
    #"neoscrypt" = "" #NeoScrypt
    #"x17" = "" #x17
   
    ### MAYBE SUPPORTED ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 20/05/2018
    ### these algorithms were not benchmarked into the leaderboard and 
    ### should be benchmarked on a per miner basis if supported by pools
    "bastion" = "" #bastion
    "bmw" = "" #bmw
    "deep" = "" #deep
    "dmd-gr" = "" #dmd-gr
    "fresh" = "" #fresh
    "fugue256" = "" #Fugue256
    "jackpot" = "" #JackPot
    "luffa" = "" #Luffa
    #"lyra2" = "" #lyra2re
    "penta" = "" #Pentablake
    "polytimos" = "" #Polytimos
    "scryptjane:nf" = "" #scryptjane:nf
    "skein2" = "" #skein2
    "veltor" = "" #Veltor
    #"whirlpool" = "" #Whirlpool
    "wildkeccak" = "" #wildkeccak
    "zr5" = "" #zr5

    ### UNSUPPORTED ALGORITHMS - AS OF 20/05/2018
    ### these algorithms were tested as unsupported by the miner but
    ### are usually profitable algorithms and should be rebenchmarked as 
    ### applicable if the miner is modified or updated
    #"bitcore" = "" #Bitcore
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"hmq1725" = "" #HMQ1725
    #"lyra2z" = "" #Lyra2z, ZCoin
    #"groestl" = "" #Groestl
    #"phi" = "" #PHI
    #"sha256t" = "" #Sha256t Sha256 triple
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"X16R" = "" #X16r
    #"X16S" = "" #X16s

    ### UNTESTED ALGORITHMS - AS OF 20/05/2018
    ### test and rank as appropriate

    ### UNPROFITABLE ALGORITHMS - AS OF 20/05/2018
    ### these algorithms have been overtaken by ASIC
    ### hardware and thus have been rendered unprofitable
    ### these were omitted from all miners and may or may not
    ### be mineable by this miner
    #"blake256R14" = "" #Decred
    #"blake256R8" = "" #VCash
    #"blake2b" = "" #SIAcoin
    #"cryptonight" = "" #Former monero algo
    #"cryptonight-lite" = "" #AEON
    #"equihash" = "" #Equihash
    #"lbry" = "" #Lbry Credits
    #"nist5" = "" #Bulwark
    #"myr-gr" = "" #Myriad-Groestl
    #"pascal" = "" #PascalCoin
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"sha256" = "" #Bitcoin also known as SHA256D (double)
    #"scrypt" = "" #Litecoin
    #"scrypt:n" = "" #ScryptN
    #"x11" = "" #Dash
    #"x11gost" = "" #Sibcoin Siberian Chervonets
    #"x13" = "" #Stratis
    #"x14" = "" #BERNcash
    #"x15" = "" #Halcyon

}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
    }
}
