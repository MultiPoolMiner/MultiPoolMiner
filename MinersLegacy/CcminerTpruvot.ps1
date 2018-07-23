using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-TPruvot\ccminer-x64.exe"
$HashSHA256 = "8051774049A412DBA64D9A699337797E7077AE45D564ECC7DEA36C0270E91F6A"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.3-tpruvot/ccminer-2.3-cuda9.7z"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "allium"        = "" #Allium
    "bastion"       = "" #Bastion
    "bitcore"       = "" #Bitcore
    "bmw"           = "" #BMW
    "cryptolight"   = "" #CryptoNightLite
    #"c11/flax"     = "" #C11
    "deep"          = "" #Deep
    "dmd-gr"        = "" #DMDGR
    #"equihash"     = "" #Equihash - Beaten by Bminer by 30%
    "fresh"         = "" #Fresh
    #"fugue256"      = "" #Fugue256 - fugue256 not in algorithms.txt
    #"graft"         = "" #CryptoNightV8 - graft not in algorithms.txt
    "groestl"       = "" #Groestl
    "hmq1725"       = "" #HMQ1725
    "jackpot"       = "" #JHA
    "keccak"        = "" #Keccak
    "keccakc"       = "" #KeccakC
    "luffa"         = "" #Luffa
    "lyra2"         = "" #Lyra2RE
    "lyra2v2"       = "" #Lyra2RE2
    "lyra2z"        = "" #Lyra2z, ZCoin
    "neoscrypt"     = "" #NeoScrypt
    "monero"        = "" #CryptoNightV7
    #"penta"         = "" #Pentablake - penta not in algorithms.txt
    "phi1612"       = "" #PHI, e.g. Seraph
    "phi2"          = "" #PHI2 LUX
    "polytimos"     = "" #Polytimos
    "scrypt-jane"   = "" #ScryptJaneNF
    "sha256t"       = "" #SHA256t
    #"skein"        = "" #Skein
    "skein2"        = "" #Skein2
    #"skunk"        = "" #Skunk
    #"sonoa"         = "" #97 hashes based on X17 ones (Sono) - sonoa not in algorithms.txt
    #"stellite"      = "" #CryptoNightV3 - stellite not in algorithms.txt
    "s3"            = "" #SHA256t
    "timetravel"    = "" #Timetravel
    "tribus"        = "" #Tribus
    "veltor"        = "" #Veltor
    "wildkeccak"    = "" #Boolberry
    #"whirlcoin"     = "" #Old Whirlcoin (Whirlpool algo) - whirlcoin not in algorithms.txt
    #"whirlpool"    = "" #WhirlPool
    "x11evo"        = "" #X11evo
    "x12"           = "" #X12
    "x16r"          = "" #X16R
    #"X16s"         = "" #X16S
    #"x17"          = "" #x17
    "zr5"           = "" #zr5

    # ASIC - never profitable 20/04/2018
    #"blake"        = "" #blake
    #"blakecoin"    = "" #Blakecoin
    #"blake2s"      = "" #Blake2s
    #"cryptonight"  = "" #CryptoNight
    #"lbry"         = "" #Lbry
    #"decred"       = "" #Decred
    #"quark"        = "" #Quark
    #"qubit"        = "" #Qubit
    #"myr-gr"       = "" #MyriadGroestl
    #"nist5"        = "" #Nist5
    #"scrypt"       = "" #Scrypt
    #"scrypt:N"     = "" #scrypt:N
    #"sha256d"      = "" #sha256d
    #"sia"          = "" #SiaCoin
    #"sib"          = "" #Sib
    #"vanilla"      = "" #BlakeVanilla
    #"x11"          = "" #X11
    #"x13"          = "" #x13
    #"x14"          = "" #x14
    #"x15"          = "" #x15
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    Switch ($Algorithm_Norm) {
        "PHI"   {$ExtendInterval = 3}
        "X16R"  {$ExtendInterval = 10}
        default {$ExtendInterval = 0}
    }

    [PSCustomObject]@{
        Type           = "NVIDIA"
        Path           = $Path
        HashSHA256     = $HashSHA256
        Arguments      = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --submit-stale"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API            = "Ccminer"
        Port           = 4068
        URI            = $Uri
        ExtendInterval = $ExtendInterval
    }
}
