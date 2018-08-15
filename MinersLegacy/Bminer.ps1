using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-CcminerSpMod\ccminer.exe"
$HashSHA256 = "8050bfde4d250c31063c7111d46c14398a3232bbc0be9b08bd258e95771ee623"
$Uri = "https://github.com/sp-hash/suprminer/releases/download/spmod-git7/raven_spmodgit7.7z"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "bastion"     = "" #Hefty Bastion
    "bitcore"     = "" #Bitcore
    "blake"       = "" #Blake 256 (SFR)
    "blake2s"     = "" #Blake2s
    "blakecoin"   = "" #Blakecoin
    "bmw"         = "" #BMW 256
    "c11"         = "" #C11
    "deep"        = "" #Deepcoin
    "dmd-gr"      = "" #Diamond-Groestl
    "equihash"    = "" #Equihash
    "fresh"       = "" #Freshcoin (shavite 80)
    "fugue256"    = "" #Fuguecoin
    "hmq1725"     = "" #HMQ1725
    "hsr"         = "" #HSR
    "jackpot"     = "" #JHA v8
    "keccak"      = "" #Keccak
    "keccakc"     = "" #Keccakc
    "luffa"       = "" #Joincoin
    "lyra2v2"     = "" #Lyra2RE2
    "lyra2z"      = "" #Lyra2z
    "neoscrypt"   = "" #NeoScrypt
    "penta"       = "" #Pentablake hash (5x Blake 512)
    "phi"         = "" #PHI
    "polytimos"   = "" #Politimos
    "quark"       = "" #Quark
    "qubit"       = "" #Qubit
    "s3"          = "" #S3 (1Coin)
    "scrypt"      = "" #Scrypt
    "scrypt-jane" = "" #Scrypt-jane Chacha
    "sha256t"     = "" #SHA256 x3
    "sia"         = "" #SIA (Blake2B)
    "skein"       = "" #Skein
    "skein2"      = "" #Double Skein (Woodcoin)
    "skunk"       = "" #Skunk
    "timetravel"  = "" #Timetravel
    "tribus"      = "" #Tribus
    "vanilla"     = "" #Blake256-8 (VNL)
    "veltor"      = "" #Thorsriddle streebog
    "whirlcoin"   = "" #Old Whirlcoin (Whirlpool algo)
    "whirlpool"   = "" #Whirlpool algo
    "wildkeccak"  = "" #Boolberry
    "x11evo"      = "" #X11evo
    "x15"         = "" #X15
    "x16r"        = "" #X16R
    "x16s"        = "" #X16S
    "x17"         = "" #X17
    "zr5"         = "" #ZR5 (ZiftrCoin)
    
    # ASIC - never profitable 11/08/2018
    #"cryptolight" = ""#AEON cryptonight (MEM/2)
    #"cryptonight" = "" #XMR cryptonight
    #"decred"      = "" #Decred
    #"groestl"     = "" #Groestl
    #"lbry"        = "" #Lbry
    #"lyra2"       = "" #CryptoCoin
    #"myr-gr"      = "" #MyriadGroestl
    #"nist5"       = "" #Nist5
    #"qubit"       = "" #Qubit
    #"quark"       = "" #Quark
    #"sib"         = "" #Sib
    #"x11"         = "" #X11
    #"x12"         = "" #X12
    #"x13"         = "" #X13
    #"x14"         = "" #X14
}

$CommonCommands = ""

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Name = (@($Name) + @("$($Miner_Device.count)x$($Miner_Device.Model_Norm | Sort-Object -unique)") | Select-Object) -join '-'

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        Switch ($Algorithm_Norm) {
            "X16R"  {$BenchmarkSamples = 50}
            "X16S"  {$BenchmarkSamples = 20}
            default {$BenchmarkSamples = 10}
        }

        [PSCustomObject]@{
            Name             = $Miner_Name
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API              = "Ccminer"
            Port             = $Miner_port
            URI              = $Uri
            BenchmarkSamples = $BenchmarkSamples
        }
    }
}
