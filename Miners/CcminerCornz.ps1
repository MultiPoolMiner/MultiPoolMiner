using module ..\Include.psm1

$Path = ".\Bin\KeccakC-NVIDIA\ccminer_CP.exe"
$HashSHA256 = "A63C6AC68D814CEC3757B345FE608DD44B59EECED6A7B4B47F5B408D0BC84CD3"
$URI = "https://github.com/cornz/ccminer/releases/download/keccakc/ccminer_CP.zip"

$Commands = [PSCustomObject]@{
    ### SUPPORTED ALGORITHMS - BEST PERFORMING MINER
    "blake2s" = "" #Blake2s XVG
    "keccak" = "" #Keccak SHA3
    "keccakc" = "" #keccakc
    "x11evo" = " -i 19" #X11evo
    "x17" = " -i 21" #x17

    ### SUPPORTED ALGORITHMS - BEAT MY ANOTHER MINER
    #"c11" = " -i 20" #c11
    #"lyra2v2" = "" #lyra2v2
    #"neoscrypt" = " -i 14" #NeoScrypt
    #"skein" = "" #Skein

    ### MAYBE SUPPORTED ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 20/05/2018
    ### these algorithms were not benchmarked into the leaderboard and 
    ### should be benchmarked on a per miner basis if supported by pools
    #"lyra2" = "" #lyra2re
    "skein2" = "" #skein2
    #"whirlpool" = "" #Whirlpool
    "veltor" = "" #Veltor

    ### UNSUPPORTED ALGORITHMS - AS OF 20/05/2018
    ### these algorithms were tested as unsupported by the miner but
    ### are usually profitable algorithms and should be rebenchmarked as 
    ### applicable if the miner is modified or updated
    #"bitcore" = "" #Bitcore
    #"ethash" = "" #Ethash
    #"equihash" = "" #Equihash
    #"groestl" = "" #Groestl
    #"hmq1725" = "" #HMQ1725
    #"hsr" = "" #HSR, HShare
    #"lyra2z" = "" #Lyra2z, ZCoin
    #"phi" = "" #PHI
    #"polytimos" = "" #Polytimos
    #"sha256t" = "" #Sha256t Sha256 triple
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"X16R" = "" #X16r
    #"X16S" = "" #X16s

    ### UNTESTED ALGORITHMS - AS OF 20/05/2018
    ### test and rank as appropriate

}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        HashSHA256 = $HashSHA256
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}
