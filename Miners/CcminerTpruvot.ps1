using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-TPruvot\ccminer.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.2.5-tpruvot/ccminer-x86-2.2.5-cuda9.7z"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "bastion" = "" #bastion
    "bitcore" = "" #Bitcore
    "bmw" = "" #bmw
    #"c11" = "" #C11
    "deep" = "" #deep
    "dmd-gr" = "" #dmd-gr
    "equihash" = "" #Equihash
    "fresh" = "" #fresh
    "fugue256" = "" #Fugue256
    "groestl" = "" #Groestl
    "hmq1725" = "" #HMQ1725
    "jackpot" = "" #JackPot
    "keccak" = "" #Keccak
    "keccakc" = "" #keccakc
    "luffa" = "" #Luffa
    "lyra2" = "" #lyra2re
    "lyra2v2" = "" #Lyra2RE2
    "lyra2z" = "" #Lyra2z, ZCoin
    "neoscrypt" = "" #NeoScrypt
    "penta" = "" #Pentablake
    "phi" = "" #PHI
    "polytimos" = "" #Polytimos
    "scryptjane:nf" = "" #scryptjane:nf
    "sha256t" = "" #sha256t
    #"skein" = "" #Skein
    "skein2" = "" #skein2
    #"skunk" = "" #Skunk
    "s3" = "" #S3
    "timetravel" = "" #Timetravel
    "tribus" = "" #Tribus
    "veltor" = "" #Veltor
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    "wildkeccak" = "" #wildkeccak
    "x11evo" = "" #X11evo
    "x12" = "" #X12
    "x16r" = "" #X16r
    "X16s" = "" #X16s
    #"x17" = "" #x17
    "zr5" = "" #zr5

    # ASIC - never profitable 20/04/2018
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"blake2s" = "" #Blake2s
    #"lbry" = "" #Lbry
    #"decred" = "" #Decred
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"scrypt" = "" #Scrypt
    #"scrypt:N" = "" #scrypt:N
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"sib" = "" #Sib
    #"vanilla" = "" #BlakeVanilla
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
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --submit-stale"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}
