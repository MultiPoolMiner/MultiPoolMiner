using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NVIDIA-Delos\ccminer.exe"
$HashSHA256 = "778E13734C2C46325A56314C5E594E141CCC637CFB26D9AC2CF53F819C22526F"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/DelosMiner/DelosMiner1.1.2.zip"
$UriManual = "https://bitcointalk.org/index.php?topic=4344544.0"
$MinerFeeInPercent = 1

$Commands = [PSCustomObject]@{
    #GPU - profitable 29/05/2018
    "bastion"     = "" # Hefty bastion, untested
    "bitcore"     = "" # Timetravel-10
    "bmw"         = "" # BMW 256, untested
    "cryptolight" = "" # AEON cryptonight (MEM/2)
    "c11/flax"    = "" # X11 variant, untested
    "deep"        = "" # Deepcoin, untested
    "equihash"    = "" # Zcash Equihash
    "dmd-gr"      = "" # Diamond-Groestl, untested
    "fresh"       = "" # Freshcoin (shavite 80), untested
    "fugue256"    = "" # Fuguecoin, untested
    "groestl"     = "" # Groestlcoin
    "hmq1725"     = "" # Doubloons / Espers
    "hsr"         = "" # HSR
    "jackpot"     = "" # JHA v8, untested
    "keccak"      = "" # Deprecated Keccak-256
    "keccakc"     = "" # Keccak-256 (CreativeCoin)
    "lbry"        = "" # LBRY Credits (Sha/Ripemd)
    "luffa"       = "" # Joincoin, untested
    "lyra2"       = "" # CryptoCoin
    "lyra2v2"     = "" # VertCoin
    "lyra2z"      = "" # ZeroCoin (3rd impl)
    "neoscrypt"   = "" # FeatherCoin, Phoenix, UFO...
    "penta"       = "" # Pentablake hash (5x Blake 512), untested
    "phi"         = "" # BHCoin
    "polytimos"   = "" # Politimos, untested
    "sha256t"     = "" # SHA256 x3
    "sib"         = "" # Sibcoin (X11+Streebog)
    "scrypt-jane" = "" # Scrypt-jane Chacha, untested
    "skein"       = "" # Skein SHA2 (Skeincoin)
    "skein2"      = "" # Double Skein (Woodcoin), untested
    "skunk"       = "" # Skein Cube Fugue Streebog
    "s3"          = "" # S3 (1Coin), untested
    "timetravel"  = "" # Machinecoin permuted x8
    "tribus"      = "" # Denarius, untested
    "vanilla"     = "" # Blake256-8 (VNL), untested
    "veltor"      = "" # Thorsriddle streebog, untested
    "whirlcoin"   = "" # Old Whirlcoin (Whirlpool algo), untested
    "whirlpool"   = "" # Whirlpool algo, untested
    "x11evo"      = "" # Permuted x11 (Revolver)
    "x16r"        = "" # X16R (Raven)
    "x16s"        = "" # X16S
    "x17"         = "" # X17
    "wildkeccak"  = "" # Boolberry, untested
    "zr5"         = "" # ZR5 (ZiftrCoin), untested
            
    # ASIC - never profitable 20/04/2018
    #"blake"      = "" #blake
    #"blakecoin"  = "" #Blakecoin
    #"blake2s"    = "" #Blake2s
    #"myr-gr"     = "" #MyriadGroestl
    #"nist5"      = "" #Nist5
    #"quark"      = "" #Quark
    #"qubit"      = "" #Qubit
    #"vanilla"    = "" #BlakeVanilla
    #scrypt"      = "" #Scrypt
    #"sha256d"    = "" #sha256d
    #"sia"        = "" #SiaCoin
    #"x11"        = "" #X11
    #"x13"        = "" #x13
    #"x14"        = "" #x14
    #"x15"        = "" #x15
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
                
if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
    $Fees = @($null)
}
else {
    $Fees = @($MinerFeeInPercent)
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week
    if ($Fees) {$HashRate = $HashRate * (1 - $MinerFeeInPercent / 100)}

    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
        Fees       = $Fees
    }
} 
