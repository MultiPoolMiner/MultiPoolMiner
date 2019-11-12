using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$HashSHA256 = "BFD886B246DB3F2A8E2E5158DDC52A651B06BD52D7B81B386B0CF0AFDA965D80"
$Uri = "https://github.com/bubasik/cpuminer-opt-yespower/releases/download/3.8.8.4/Cpuminer-opt-yespower-ytn-ver3.zip"
$ManualUri = "https://github.com/bubasik/cpuminer-opt-yespower"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    ### CPU PROFITABLE ALGOS AS OF 31/03/2019
    ### these algorithms are profitable algorithms on supported pools
    "allium"        = " -a allium" #Garlicoin (GRLC)
    "hmq1725"       = " -a hmq1725" #Espers
    "hodl"          = " -a hodl" #Hodlcoin
    "lyra2z"        = " -a lyra2z" #Zcoin (XZC)
    "m7m"           = " -a m7m" #Magi (XMG)
    "x12"           = " -a x12" #Galaxie Cash (GCH)
    "yescrypt"      = " -a yescrypt" #Globlboost-Y (BSTY)
    "yescryptr16"   = " -a yescryptr16" #Yenten (YTN)

    ### MAYBE PROFITABLE ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 30/03/2019
    ### these algorithms are not mineable on supported pools but may be profitable
    ### once/if support begins. They should be classified accordingly when or if
    ### an algo becomes supported by one of the pools.
    "anime"         = " -a anime" #Animecoin (ANI)
    "argon2"        = " -a argon2" #Argon2 Coin (AR2)
    "argon2d250"    = " -a argon2d250" #argon2d-crds, Credits (CRDS)
    "argon2d500"    = " -a argon2d500" #argon2d-dyn, Dynamic (DYN)
    "argon2d4096"   = " -a argon2d4096" #argon2d-uis, Unitus (UIS)
    "axiom"         = " -a axiom" #Shabal-256 MemoHash
    "bastion"       = " -a bastion" #
    "bmw"           = " -a bmw" #BMW 256
    "deep"          = " -a deep" #Deepcoin (DCN)
    "drop"          = " -a drop" #Dropcoin
    "fresh"         = " -a fresh" #Fresh
    "heavy"         = " -a heavy" #Heavy
    "jha"           = " -a jha" #jackppot (Jackpotcoin)
    "luffa"         = " -a luffa" #Luffa
    "lyra2rev2"     = " -a lyra2rev2" #lyrav2, Vertcoin
    "lyra2z330"     = " -a lyra2z330" #Lyra2 330 rows, Zoin (ZOI)
    "pentablake"    = " -a pentablake" #5 x blake512
    "pluck"         = " -a pluck" #Pluck:128 (Supcoin)
    "polytimos"     = " -a polytimos" #
    "quark"         = " -a quark" #Quark
    "qubit"         = " -a qubit" #Qubit
    "scrypt"        = " -a scrypt" #scrypt(1024, 1, 1) (default)
    "scryptjane:nf" = " -a scryptjane:nf" #
    "shavite3"      = " -a shavite3" #Shavite3
    "timetravel10"  = " -a timetravel10" #Bitcore (BTX)
    "veltor"        = " -a veltor" #
    "whirlpool"     = " -a whirlpool" #
    "x11"           = " -a x11" #Dash
    "x11gost"       = " -a x11gost" #sib (SibCoin)
    "xevan"         = " -a xevan" #Bitsend (BSD)
    "yescryptr8"    = " -a yescryptr8" #BitZeny (ZNY)
    "yescryptr32"   = " -a yescryptr32" #WAVI
    "zr5"           = " -a zr5" #Ziftr

    #GPU or ASIC - never profitable 30/03/2019
    #"blake"         = " -a blake" #blake256r14 (SFR)
    #"blakecoin"     = " -a blakecoin" #blake256r8
    #"blake2s"       = " -a blake2s" #Blake-2 S
    #"cryptolight"   = " -a cryptolight" #Cryptonight-light
    #"cryptonight"   = " -a cryptonight" #Cryptonote legacy
    #"cryptonightv7" = " -a cryptonightv7" #variant 7
    #"c11"           = " -a c11" #Chaincoin
    #"decred"        = " -a decred" #Blake256r14dcr
    #"dmd-gr"        = " -a dmd-gr" #Diamond
    #"groestl"       = " -a groestl" #Groestl coin
    #"keccak"        = " -a keccak" #Maxcoin
    #"keccakc"       = " -a keccakc" #Creative Coin
    #"lbry"          = " -a lbry" #LBC, LBRY Credits
    #"lyra2h"        = " -a lyra2h" #Hppcoin
    #"lyra2re"       = " -a lyra2re" #lyra2
    #"myr-gr"        = " -a myr-gr" #Myriad-Groestl
    #"neoscrypt"     = " -a neoscrypt" #NeoScrypt(128, 2, 1)
    #"nist5"         = " -a nist5" #Nist5
    #"phi1612"       = " -a phi1612" #phi, LUX coin
    #"scrypt:N"      = " -a scrypt:N" #scrypt(N, 1, 1)
    #"sha256d"       = " -a sha256d" #Double SHA-256
    #"sha256t"       = " -a sha256t" #Triple SHA-256, Onecoin (OC)
    #"skunk"         = " -a skunk" #Signatum (SIGT)
    #"skein"         = " -a skein" #Skein+Sha (Skeincoin)
    #"skein2"        = " -a skein2" #Double Skein (Woodcoin)
    #"tribus"        = " -a tribus" #Denarius (DNR)
    #"vanilla"       = " -a vanilla" #blake256r8vnl (VCash)
    #"whirlpoolx"    = " -a whirlpoolx" #
    #"x11evo"        = " -a x11evo" #Revolvercoin (XRE)
    #"x13"           = " -a x13" #X13
    #"x13sm3"        = " -a x13sm3" #hsr (Hshare)
    #"x14"           = " -a x14" #X14
    #"x15"           = " -a x15" #X15
    #"x16r"          = " -a x16r" #x16r
    #"x16s"          = " -a x16s" #X16s
    #"x17"           = " -a x17" #X17
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices = $Devices | Where-Object Type -EQ "CPU"
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Devices | Select-Object -First 1 -ExpandProperty Id) + 1

    $Paths = @()
    if ($Miner_Device.CpuFeatures -match "avx")               {$Paths += ".\Bin\$($Name)\cpuminer-Avx.exe"}
    if ($Miner_Device.CpuFeatures -match "(avx2|[^sha]){2}")  {$Paths += ".\Bin\$($Name)\cpuminer-Avx2.exe"}
    if ($Miner_Device.CpuFeatures -match "(avx2|sha){2}")     {$Paths += ".\Bin\$($Name)\cpuminer-Avx2-Sha.exe"}
    if ($Miner_Device.CpuFeatures -match "sse2")              {$Paths += ".\Bin\$($Name)\cpuminer-Sse2.exe"}
    if ($Miner_Device.CpuFeatures -match "(aes|sse42){2}")    {$Paths += ".\Bin\$($Name)\cpuminer-Aes-Sse42.exe"}
    if (-not $Paths) {$Paths = @(".\Bin\$($Name)\cpuminer.exe")}

    $Paths | ForEach-Object {
        $Path = $_
        $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
            $Miner_Name = (@($Name -replace "_", "$(($Path -split "\\" | Select-Object -Last 1) -replace "cpuminer" -replace ".exe" -replace "-")_") + @(($Devices.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) -join '-') | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $Commands.$_ -DeviceIDs $Miner_Device.Type_Vendor_Index

            Switch ($Algorithm_Norm) {
                "C11"   {$WarmupTime = 60}
                default {$WarmupTime = 30}
            }
    
            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Ccminer"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 0.1 / 100}
                WarmupTime = $WarmupTime #seconds
            }
        }
    }
}
