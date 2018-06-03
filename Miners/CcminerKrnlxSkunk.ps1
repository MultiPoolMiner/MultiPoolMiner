using module ..\Include.psm1

$Path = ".\Bin\Skunk-NVIDIAkrnlx\ccminer-x64-80.exe"
$URI = "http://ccminer.org/preview/ccminer-skunk-krnlx-80.7z"

$Commands = [PSCustomObject]@{
    ### SUPPORTED ALGORITHMS - BEST PERFORMING MINER
    "bitcore" = "" #Bitcore

    ### SUPPORTED ALGORITHMS - BEAT MY ANOTHER MINER
    #"blake2s" = "" #Blake2s XVG
    #"c11" = "" #c11
    #"equihash" = "" #Equihash
    #"groestl" = "" #Groestl
    #"hmq1725" = "" #HMQ1725
    #"keccak" = "" #Keccak SHA3
    #"lyra2v2" = "" #lyra2v2
    #"lyra2z" = "" #Lyra2z, ZCoin
    #"neoscrypt" = "" #NeoScrypt
    #"sha256t" = "" #Sha256t Sha256 triple
    #"skein" = "" #Skein
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"x11evo" = "" #X11evo
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
    "heavy" = "" #HeavyCoin
    "jackpot" = "" #JackPot
    "luffa" = "" #Luffa
    #"lyra2" = "" #lyra2re
    "mjollnir" = "" #Mjollnircoin
    "penta" = "" #Pentablake
    "polytimos" = "" #Polytimos
    "scryptjane:nf" = "" #scryptjane:nf
    "skein2" = "" #skein2
    #"whirlpool" = "" #Whirlpool
    "veltor" = "" #Veltor
    "wildkeccak" = "" #wildkeccak
    "zr5" = "" #zr5

    ### UNSUPPORTED ALGORITHMS - AS OF 20/05/2018
    ### these algorithms were tested as unsupported by the miner but
    ### are usually profitable algorithms and should be rebenchmarked as 
    ### applicable if the miner is modified or updated
    #"ethash" = "" #Ethash
    #"hsr" = "" #HSR, HShare
    #"keccakc" = "" #keccakc
    #"phi" = "" #PHI
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
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}