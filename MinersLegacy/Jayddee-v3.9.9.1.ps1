using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$HashSHA256 = ""
$Uri = "https://github.com/JayDDee/cpuminer-opt/releases/download/v3.9.9.1/cpuminer-opt-3.9.9.1-windows.zip"
$ManualUri = "https://github.com/JayDDee/cpuminer-opt"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) { $Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*" }

$Devices = $Devices | Where-Object Type -EQ "CPU"

if ($Devices.CpuFeatures -match "avx2")     { $Miner_Path = ".\Bin\$($Name)\cpuminer-Avx2.exe" }
elseif ($Devices.CpuFeatures -match "avx")  { $Miner_Path = ".\Bin\$($Name)\cpuminer-Avx.exe" }
elseif ($Devices.CpuFeatures -match "aes")  { $Miner_Path = ".\Bin\$($Name)\cpuminer-Aes-Sse42.exe" }
elseif ($Devices.CpuFeatures -match "sse2") { $Miner_Path = ".\Bin\$($Name)\cpuminer-Sse2.exe" }
else { return }

$Commands = [PSCustomObject]@{ 
    ### CPU PROFITABLE ALGOS AS OF 30/03/2019
    ### these algorithms are profitable algorithms on supported pools
    "allium"        = " -a allium" #Garlicoin
    "blake2b"       = " -a blake2b" #Blake2b, new in 3.9.6.2
    "bmw512"        = " -a bmw512" #Bmw512, new in 3.9.6
    "hex"           = " -a hex" #Hex, new in 3.9.6.1
    "hmq1725"       = " -a hmq1725" #HMQ1725
    "hodl"          = " -a hodl" #Hodlcoin
    "lyra2z330"     = " -a lyra2z330" #Lyra2z330
    "m7m"           = " -a m7m" #m7m
    "x12"           = " -a x12" #x12
    "phi2"          = " -a phi2" #phi2
    "yespower"      = " -a yespower" #Yespower
    "yespowerr16"   = " -a yespowerr16" #YespowerR16
    "yescrypt"      = " -a yescrypt" #Yescrypt
    "yescryptr16"   = " -a yescryptr16" #YescryptR16
    "x16rtgincoin"  = " -a x16rt" #X16rt, new in 3.9.6
    "x16rtveil"     = " -a x16rt-veil" #X16rt-veil, new in 3.9.6
    "x16rv2"        = " -a x16rv2" #X16rt-veil, new in 3.9.8
    "x13bcd"        = " -a x13bcd" #X13bcd, new in 3.9.6
    "x21s"          = " -a x21s" #X212, new in 3.9.6
    ### MAYBE PROFITABLE ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 30/03/20198
    ### these algorithms are not mineable on supported pools but may be profitable
    ### once/if support begins. They should be classified accordingly when or if
    ### an algo becomes supported by one of the pools.
    "anime"         = " -a anime" #Anime 
    "argon2"        = " -a argon2" #Argon2
    "argon2d-crds"  = " -a argon2d-crds" #Argon2Credits
    "argon2d-dyn"   = " -a argon2d-dyn" #Argon2Dynamic
    "argon2d-uis"   = " -a argon2d-uis" #Argon2Unitus
    #"axiom"         = " -a axiom" #axiom
    "bastion"       = " -a bastion" #bastion
    #"bitcore"       = " -a bitcore" #Timetravel10 and Bitcore are technically the same
    "bmw"           = " -a bmw" #bmw
    "deep"          = " -a deep" #deep
    "drop"          = " -a drop" #drop    
    "fresh"         = " -a fresh" #fresh
    "heavy"         = " -a heavy" #heavy
    "jha"           = " -a jha" #JHA
    "pentablake"    = " -a pentablake" #pentablake
    "pluck"         = " -a pluck" #pluck
    "scryptjane:nf" = " -a scryptjane:nf" #scryptjane:nf
    "shavite3"      = " -a shavite3" #shavite3
    "skein2"        = " -a skein2" #skein2
    "timetravel"    = " -a timetravel" #Timetravel
    "timetravel10"  = " -a timetravel10" #Timetravel10
    "veltor"        = " -a veltor" #Veltor
    "yescryptr8"    = " -a yescryptr8" #yescryptr8
    "yescryptr32"   = " -a yescryptr32" #yescryptr32, WAVI
    "zr5"           = " -a zr5" #zr5

    #GPU or ASIC - never profitable 30/03/2019
    #"blake"         = " -a blake" #blake
    #"blakecoin"     = " -a blakecoin" #Blakecoin
    #"blake2s"       = " -a blake2s" #Blake2s
    #"cryptolight"   = " -a cryptolight" #cryptolight
    #"cryptonight"   = " -a cryptonight" #Cryptonight
    #"cryptonightv7" = " -a cryptonightv7" #CryptoNightV7
    #"c11"           = " -a c11" #C11
    #"decred"        = " -a decred" #Decred
    #"dmd-gr"        = " -a dmd-gr" #dmd-gr
    #"equihash"      = " -a equihash" #Equihash
    #"ethash"        = " -a ethash" #Ethash
    #"groestl"       = " -a groestl" #Groestl
    #"keccak"        = " -a keccak" #Keccak
    #"keccakc"       = " -a keccakc" #keccakc
    #"lbry"          = " -a lbry" #Lbry
    #"lyra2v2"       = " -a lyra2v2" #Lyra2RE2
    #"lyra2h"        = " -a lyra2h" #lyra2h
    #"lyra2re"       = " -a lyra2re" #lyra2re
    #"lyra2z"        = " -a lyra2z" #Lyra2z, ZCoin
    #"myr-gr"        = " -a myr-gr" #MyriadGroestl
    #"neoscrypt"     = " -a neoscrypt" #NeoScrypt
    #"nist5"         = " -a nist5" #Nist5
    #"pascal"        = " -a pascal" #Pascal
    #"phi1612"       = " -a phi1612" #phi1612
    #"scrypt:N"      = " -a scrypt:N" #scrypt:N
    #"sha256d"       = " -a sha256d" #sha256d
    #"sha256t"       = " -a sha256t" #sha256t
    #"sib"           = " -a sib" #Sib
    #"skunk"         = " -a skunk" #Skunk
    #"skein"         = " -a skein" #Skein
    #"tribus"        = " -a tribus" #Tribus
    #"vanilla"       = " -a vanilla" #BlakeVanilla
    #"whirlpoolx"    = " -a whirlpoolx" #whirlpoolx
    #"x11evo"        = " -a x11evo" #X11evo
    #"x13"           = " -a x13" #x13
    #"x13sm3"        = " -a x13sm3" #x13sm3
    #"x14"           = " -a x14" #x14
    #"x15"           = " -a x15" #x15
    #"x16r"          = " -a x16r" #x16r
    #"x16s"          = " -a x16s" #X16s
    #"x17"           = " -a x17" #X17
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Devices | Select-Object -First 1 -ExpandProperty Id) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_; $_ } | Where-Object { -not ($Algorithm_Norm -eq "X16Rt" -and $Pools.$Algorithm_Norm.Coin -eq "Veil" <#temp fix; x16rt is not for veil#>) } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> } | ForEach-Object { 
        $Miner_Name = (@($Name -replace "_", "$(($Miner_Path -split "\\" | Select-Object -Last 1) -replace "cpuminer" -replace ".exe" -replace "-")_") + @(($Devices.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) -join '-') | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) { 
            "C11"   { $WarmupTime = 60 }
            default { $WarmupTime = 30 }
        }

        [PSCustomObject]@{ 
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Devices.Name
            Path       = $Miner_Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommomCommands -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            WarmupTime = 45 #seconds
        }
    }
}
