using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-KlausT\ccminer.exe"
$HashSHA256 = "EBF91E27F54DE29F158A4F5EBECEDB7E7E03EB9010331B2E949335BF1144A886"
$Uri = "https://github.com/KlausT/ccminer/releases/download/8.21/ccminer-821-cuda91-x64.zip"

$Commands = [PSCustomObject]@{
    ### SUPPORTED ALGORITHMS - BEST PERFORMING MINER
    "groestl" = "" #Groestl

    ### SUPPORTED ALGORITHMS - BEAT MY ANOTHER MINER
    #"c11" = "" #c11
    #"keccak" = "" #Keccak SHA3
    #"lyra2v2" = "" #lyra2v2
    #"neoscrypt" = "" #NeoScrypt
    #"sha256t" = "" #Sha256t Sha256 triple
    #"skein" = "" #Skein
    #"x17" = "" #x17
    
    ### MAYBE SUPPORTED ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 20/05/2018
    ### these algorithms were not benchmarked into the leaderboard and 
    ### should be benchmarked on a per miner basis if supported by pools
    "deep" = "" #deep
    "dmd-gr" = "" #dmd-gr
    "fresh" = "" #fresh
    "fugue256" = "" #Fugue256
    "jackpot" = "" #JackPot
    "luffa" = "" #Luffa
    "penta" = "" #Pentablake
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx

    ### UNSUPPORTED ALGORITHMS - AS OF 20/05/2018
    ### these algorithms were tested as unsupported by the miner but
    ### are usually profitable algorithms and should be rebenchmarked as 
    ### applicable if the miner is modified or updated
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s XVG
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"hmq1725" = "" #HMQ1725
    #"hsr" = "" #HSR, HShare
    #"keccakc" = "" #keccakc
    #"lyra2z" = "" #Lyra2z, ZCoin
    #"phi" = "" #PHI
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"x11evo" = "" #X11evo
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
        Arguments  = "-a $_ -b 4068 -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
    }
}
