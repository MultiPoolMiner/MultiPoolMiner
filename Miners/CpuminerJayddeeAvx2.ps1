using module ..\Include.psm1

$Path = ".\Bin\CPU-JayDDee\cpuminer-avx2.exe"
$Uri = "https://github.com/JayDDee/cpuminer-opt/files/1939225/cpuminer-opt-3.8.8-windows.zip"

$Commands = [PSCustomObject]@{
    # CPU Only algos 23/04/2018
    "anime" = "" #Anime 
    "argon2" = "" #Argon2
    "argon2d-crds" = "" #Argon2Credits
    "argon2d-dyn" = "" #Argon2Dynamic
    "argon2d-uis" = "" #Argon2Unitus
    #"axiom" = "" #axiom
    "drop" = "" #drop    
    "lyra2z330" = "" #lyra2z330
    "m7m" = "" #m7m

    # CPU & GPU - still profitable 23/04/2018
    "lyra2z" = "" #Lyra2z, ZCoin
    "hmq1725" = "" #HMQ1725
    "shavite3" = "" #shavite3
    "x12" = "" #x12
    "cryptonightv7" = "" #CryptoNightV7XMR
    "yescrypt" = "" #Yescrypt
    "yescryptr8" = "" #yescryptr8
    "yescryptr16" = "" #yescryptr16, YENTEN
    "yescryptr32" = "" #yescryptr32, WAVI

    #GPU or ASIC - never profitable 23/04/2018
    #"allium" = "" #Allium
    #"bastion" = "" #bastion
    #"bitcore" = "" #Bitcore
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"blake2s" = "" #Blake2s
    #"bmw" = "" #bmw
    #"cryptolight" = "" #cryptolight
    #"cryptonight" = "" #CryptoNight
    #"c11" = "" #C11
    #"decred" = "" #Decred
    #"deep" = "" #deep
    #"dmd-gr" = "" #dmd-gr
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"fresh" = "" #fresh
    #"groestl" = "" #Groestl
    #"heavy" = "" #heavy
    #"jha" = "" #JHA
    #"keccak" = "" #Keccak
    #"keccakc" = "" #keccakc
    #"lbry" = "" #Lbry
    #"lyra2v2" = "" #Lyra2RE2
    #"lyra2h" = "" #lyra2h
    #"lyra2re" = "" #lyra2re
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = "" #NeoScrypt
    #"nist5" = "" #Nist5
    #"pascal" = "" #Pascal
    #"pentablake" = "" #pentablake
    #"phi1612" = "" #phi1612
    #"pluck" = "" #pluck
    #"scrypt:N" = "" #scrypt:N
    #"scryptjane:nf" = "" #scryptjane:nf
    #"sha256d" = "" #sha256d
    #"sha256t" = "" #sha256t
    #"sib" = "" #Sib
    #"skunk" = "" #Skunk
    #"skein" = "" #Skein
    #"skein2" = "" #skein2
    #"timetravel" = "" #Timetravel
    #"timetravel10" = "" #timetravel10
    #"tribus" = "" #Tribus
    #"vanilla" = "" #BlakeVanilla
    #"veltor" = "" #Veltor
    #"whirlpoolx" = "" #whirlpoolx
    #"x11evo" = "" #X11evo
    #"x13" = "" #x13
    #"x13sm3" = "" #x13sm3
    #"x14" = "" #x14
    #"x15" = "" #x15
    #"x16r" = "" #x16r
    #"x16s" = "" #X16s
    #"x17" = "" #X17
    #"zr5" = "" #zr5
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "CPU"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4048
        URI = $Uri
    }
}
