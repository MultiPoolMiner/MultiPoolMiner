using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$HashSHA256 = ""
$Uri = "https://github.com/JayDDee/cpuminer-opt/releases/download/v3.9.6.1/cpuminer-opt-3.9.6.1-windows.zip"
$ManualUri = "https://github.com/JayDDee/cpuminer-opt"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = $Devices | Where-Object Type -EQ "CPU"

if ($Devices.CpuFeatures -match "avx2")     {$Miner_Path = ".\Bin\$($Name)\cpuminer-Avx2.exe"}
elseif ($Devices.CpuFeatures -match "avx")  {$Miner_Path = ".\Bin\$($Name)\cpuminer-Avx.exe"}
elseif ($Devices.CpuFeatures -match "aes")  {$Miner_Path = ".\Bin\$($Name)\cpuminer-Aes-Sse42.exe"}
elseif ($Devices.CpuFeatures -match "sse2") {$Miner_Path = ".\Bin\$($Name)\cpuminer-Sse2.exe"}
else {return}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        ### CPU PROFITABLE ALGOS AS OF 30/03/2019
        ### these algorithms are profitable algorithms on supported pools
        "allium"        = "" #Garlicoin
        "bmw512"        = "" #Bmw512, new in 3.9.6
        "hex"           = "" #Hex, new in 3.9.6.1
        "hmq1725"       = "" #HMQ1725
        "hodl"          = "" #Hodlcoin
        "lyra2z330"     = "" #Lyra2z330
        "m7m"           = "" #m7m
        "x12"           = "" #x12
        "yespower"      = "" #Yespower
        "yespowerr16"   = "" #YespowerR16
        "yescrypt"      = "" #Yescrypt
        "yescryptr16"   = "" #YescryptR16
        "x16rt"         = "" #X16rt, new in 3.9.6
        "x16rt-veil"    = "" #X16rt-veil, new in 3.9.6
        "x13bcd"        = "" #X13bcd, new in 3.9.6
        "x21s"          = "" #X212, new in 3.9.6
        ### MAYBE PROFITABLE ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 30/03/20198
        ### these algorithms are not mineable on supported pools but may be profitable
        ### once/if support begins. They should be classified accordingly when or if
        ### an algo becomes supported by one of the pools.
        "anime"         = "" #Anime 
        "argon2"        = "" #Argon2
        "argon2d-crds"  = "" #Argon2Credits
        "argon2d-dyn"   = "" #Argon2Dynamic
        "argon2d-uis"   = "" #Argon2Unitus
        #"axiom"         = "" #axiom
        "bastion"       = "" #bastion
        #"bitcore"       = "" #Timetravel10 and Bitcore are technically the same
        "bmw"           = "" #bmw
        "deep"          = "" #deep
        "drop"          = "" #drop    
        "fresh"         = "" #fresh
        "heavy"         = "" #heavy
        "jha"           = "" #JHA
        "pentablake"    = "" #pentablake
        "pluck"         = "" #pluck
        "scryptjane:nf" = "" #scryptjane:nf
        "shavite3"      = "" #shavite3
        "skein2"        = "" #skein2
        "timetravel"    = "" #Timetravel
        "timetravel10"  = "" #Timetravel10
        "veltor"        = "" #Veltor
        "yescryptr8"    = "" #yescryptr8
        "yescryptr32"   = "" #yescryptr32, WAVI
        "zr5"           = "" #zr5

        #GPU or ASIC - never profitable 30/03/2019
        #"blake"         = "" #blake
        #"blakecoin"     = "" #Blakecoin
        #"blake2s"       = "" #Blake2s
        #"cryptolight"   = "" #cryptolight
        #"cryptonight"   = "" #Cryptonight
        #"cryptonightv7" = "" #CryptoNightV7
        #"c11"           = "" #C11
        #"decred"        = "" #Decred
        #"dmd-gr"        = "" #dmd-gr
        #"equihash"      = "" #Equihash
        #"ethash"        = "" #Ethash
        #"groestl"       = "" #Groestl
        #"keccak"        = "" #Keccak
        #"keccakc"       = "" #keccakc
        #"lbry"          = "" #Lbry
        #"lyra2v2"       = "" #Lyra2RE2
        #"lyra2h"        = "" #lyra2h
        #"lyra2re"       = "" #lyra2re
        #"lyra2z"        = "" #Lyra2z, ZCoin
        #"myr-gr"        = "" #MyriadGroestl
        #"neoscrypt"     = "" #NeoScrypt
        #"nist5"         = "" #Nist5
        #"pascal"        = "" #Pascal
        #"phi1612"       = "" #phi1612
        #"scrypt:N"      = "" #scrypt:N
        #"sha256d"       = "" #sha256d
        #"sha256t"       = "" #sha256t
        #"sib"           = "" #Sib
        #"skunk"         = "" #Skunk
        #"skein"         = "" #Skein
        #"tribus"        = "" #Tribus
        #"vanilla"       = "" #BlakeVanilla
        #"whirlpoolx"    = "" #whirlpoolx
        #"x11evo"        = "" #X11evo
        #"x13"           = "" #x13
        #"x13sm3"        = "" #x13sm3
        #"x14"           = "" #x14
        #"x15"           = "" #x15
        #"x16r"          = "" #x16r
        #"x16s"          = "" #X16s
        #"x17"           = "" #X17
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Devices | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name -replace "_", "$(($Miner_Path -split "\\" | Select-Object -Last 1) -replace "cpuminer" -replace ".exe" -replace "-")_") + @(($Devices.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '-') | Select-Object) -join '-'

        #Get parameters for active miner devices
        if ($Miner_Config.Parameters.$Algorithm_Norm) {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
        }
        elseif ($Miner_Config.Parameters."*") {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
        }
        else {
            $Parameters = Get-ParameterPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Devices.Name
            Path       = $Miner_Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port$Parameters$CommonParameters" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            WarmupTime = 45 #seconds
        }
    }
}
