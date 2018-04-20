using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-RavenMiner\ccminer.exe"
$Uri = "https://github.com/Ravencoin-Miner/Ravencoin/releases/download/v2.5.1/Ravencoin.Miner.v2.5.1.COLOR.zip"

$Commands = [PSCustomObject]@{
    #GPU - profitable 27/03/2018
    "bastion" = "" #bastion
    "bitcore" = "" #Bitcore
    "blake" = "" #blake
    "blakecoin" = "" #Blakecoin
    "bmw" = "" #bmw
    "cryptolight" = "" #cryptolight
    "cryptonight" = "" #CryptoNight
    "c11" = "" #C11
    "deep" = "" #deep
    "dmd-gr" = "" #dmd-gr
    "equihash" = "" #Equihash
    "fresh" = "" #fresh
    "fugue256" = "" #Fugue256
    "groestl" = "" #Groestl
    "hmq1725" = "" #HMQ1725
    "keccak" = "" #Keccak
    "keccakc" = "" #keccakc
    "jackpot" = "" #JackPot
    "luffa" = "" #Luffa
    "lyra2v2" = "" #Lyra2RE2
    "lyra2re" = "" #lyra2re
    "lyra2z" = "" #Lyra2z, ZCoin
    "myr-gr" = "" #MyriadGroestl
    "neoscrypt" = "" #NeoScrypt
    "nist5" = "" #Nist5
    "pentablake" = "" #pentablake
    "penta" = "" #Pentablake
    "phi" = "" #PHI
    "polytimos" = "" #Polytimos
    "scryptjane:nf" = "" #scryptjane:nf
    "sha256t" = "" #sha256t
    "sib" = "" #Sib
    "skein" = "" #Skein
    "skein2" = "" #skein2
    "skunk" = "" #Skunk
    "s3" = "" #S3
    "timetravel" = "" #Timetravel
    "tribus" = "" #Tribus
    "vanilla" = "" #BlakeVanilla
    "veltor" = "" #Veltor
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    "wildkeccak" = "" #wildkeccak
    "x11evo" = "" #X11evo
    "x16r" = "" #X16r
    "x17" = "" #x17
    "zr5" = "" #zr5

    # ASIC - never profitable 27/03/2018
    #"blake2s" = "" #Blake2s
    #"lbry" = "" #Lbry
    #"decred" = "" #Decred
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"scrypt:N" = "" #scrypt:N
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"x11" = "" #X11
    #"x13" = "" #x13
    #"x14" = "" #x14
    #"x15" = "" #x15
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
        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
        PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
    }
}