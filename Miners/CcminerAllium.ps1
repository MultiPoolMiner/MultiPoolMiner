using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Allium\ccminer-x64.exe"
$HashSHA256 = "70117C8CBADB642E5E1C587FA0CA3AE1B910FCC0A030CA8884750332DB89D95B"
$Uri = "http://ccminer.org/preview/ccminer-x64-2.2.6-xmr-allium-cuda9.7z"

$Commands = [PSCustomObject]@{
    ### SUPPORTED ALGORITHMS - BEST PERFORMING MINER
    "allium" = "" #Garlicoin
    "lyra2z" = "" #Lyra2z, ZCoin
    "sha256t" = "" #Sha256t Sha256 triple
    "timetravel" = "" #Timetravel
    "tribus" = "" #Tribus

    ### SUPPORTED ALGORITHMS - BEAT MY ANOTHER MINER
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s XVG
    #"c11" = "" #c11
    #"equihash" = "" #Equihash
    #"hmq1725" = "" #HMQ1725
    #"hsr" = "" #HSR, HShare
    #"groestl" = "" #Groestl
    #"keccak" = "" #Keccak SHA3
    #"keccakc" = "" #keccakc
    #"lyra2v2" = "" #lyra2v2
    #"phi" = "" #PHI
    #"polytimos" = "" #Polytimos
    #"neoscrypt" = "" #NeoScrypt
    #"skein" = "" #Skein
    #"skunk" = "" #Skunk
    #"x11evo" = "" #X11evo
    #"X16R" = "" #X16r
    #"X16S" = "" #X16s
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
    "scryptjane:nf" = "" #scryptjane:nf
    "skein2" = "" #skein2
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    "wildkeccak" = "" #wildkeccak
    "x12" = "" #X12
    "zr5" = "" #zr5
    "veltor" = "" #Veltor

    ### UNSUPPORTED ALGORITHMS - AS OF 20/05/2018
    ### these algorithms were tested as unsupported by the miner but
    ### are usually profitable algorithms and should be rebenchmarked as 
    ### applicable if the miner is modified or updated
    #"ethash" = "" #Ethash

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
