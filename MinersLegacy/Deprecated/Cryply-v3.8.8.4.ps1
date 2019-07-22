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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        ### CPU PROFITABLE ALGOS AS OF 31/03/2019
        ### these algorithms are profitable algorithms on supported pools
        "allium"        = "" #Garlicoin (GRLC)
        "hmq1725"       = "" #Espers
        "hodl"          = "" #Hodlcoin
        "lyra2z"        = "" #Zcoin (XZC)
        "m7m"           = "" #Magi (XMG)
        "x12"           = "" #Galaxie Cash (GCH)
        "yescrypt"      = "" #Globlboost-Y (BSTY)
        "yescryptr16"   = "" #Yenten (YTN)

        ### MAYBE PROFITABLE ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 30/03/2019
        ### these algorithms are not mineable on supported pools but may be profitable
        ### once/if support begins. They should be classified accordingly when or if
        ### an algo becomes supported by one of the pools.
        "anime"         = "" #Animecoin (ANI)
        "argon2"        = "" #Argon2 Coin (AR2)
        "argon2d250"    = "" #argon2d-crds, Credits (CRDS)
        "argon2d500"    = "" #argon2d-dyn, Dynamic (DYN)
        "argon2d4096"   = "" #argon2d-uis, Unitus (UIS)
        "axiom"         = "" #Shabal-256 MemoHash
        "bastion"       = "" #
        "bmw"           = "" #BMW 256
        "deep"          = "" #Deepcoin (DCN)
        "drop"          = "" #Dropcoin
        "fresh"         = "" #Fresh
        "heavy"         = "" #Heavy
        "jha"           = "" #jackppot (Jackpotcoin)
        "luffa"         = "" #Luffa
        "lyra2rev2"     = "" #lyrav2, Vertcoin
        "lyra2z330"     = "" #Lyra2 330 rows, Zoin (ZOI)
        "pentablake"    = "" #5 x blake512
        "pluck"         = "" #Pluck:128 (Supcoin)
        "polytimos"     = "" #
        "quark"         = "" #Quark
        "qubit"         = "" #Qubit
        "scrypt"        = "" #scrypt(1024, 1, 1) (default)
        "scryptjane:nf" = "" #
        "shavite3"      = "" #Shavite3
        "timetravel10"  = "" #Bitcore (BTX)
        "veltor"        = "" #
        "whirlpool"     = "" #
        "x11"           = "" #Dash
        "x11gost"       = "" #sib (SibCoin)
        "xevan"         = "" #Bitsend (BSD)
        "yescryptr8"    = "" #BitZeny (ZNY)
        "yescryptr32"   = "" #WAVI
        "zr5"           = "" #Ziftr

        #GPU or ASIC - never profitable 30/03/2019
        #"blake"         = "" #blake256r14 (SFR)
        #"blakecoin"     = "" #blake256r8
        #"blake2s"       = "" #Blake-2 S
        #"cryptolight"   = "" #Cryptonight-light
        #"cryptonight"   = "" #Cryptonote legacy
        #"cryptonightv7" = "" #variant 7
        #"c11"           = "" #Chaincoin
        #"decred"        = "" #Blake256r14dcr
        #"dmd-gr"        = "" #Diamond
        #"groestl"       = "" #Groestl coin
        #"keccak"        = "" #Maxcoin
        #"keccakc"       = "" #Creative Coin
        #"lbry"          = "" #LBC, LBRY Credits
        #"lyra2h"        = "" #Hppcoin
        #"lyra2re"       = "" #lyra2
        #"myr-gr"        = "" #Myriad-Groestl
        #"neoscrypt"     = "" #NeoScrypt(128, 2, 1)
        #"nist5"         = "" #Nist5
        #"phi1612"       = "" #phi, LUX coin
        #"scrypt:N"      = "" #scrypt(N, 1, 1)
        #"sha256d"       = "" #Double SHA-256
        #"sha256t"       = "" #Triple SHA-256, Onecoin (OC)
        #"skunk"         = "" #Signatum (SIGT)
        #"skein"         = "" #Skein+Sha (Skeincoin)
        #"skein2"        = "" #Double Skein (Woodcoin)
        #"tribus"        = "" #Denarius (DNR)
        #"vanilla"       = "" #blake256r8vnl (VCash)
        #"whirlpoolx"    = "" #
        #"x11evo"        = "" #Revolvercoin (XRE)
        #"x13"           = "" #X13
        #"x13sm3"        = "" #hsr (Hshare)
        #"x14"           = "" #X14
        #"x15"           = "" #X15
        #"x16r"          = "" #x16r
        #"x16s"          = "" #X16s
        #"x17"           = "" #X17
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices = $Devices | Where-Object Type -EQ "CPU"
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Devices | Select-Object -First 1 -ExpandProperty Index) + 1

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
            $Miner_Name = (@($Name -replace "_", "$(($Path -split "\\" | Select-Object -Last 1) -replace "cpuminer" -replace ".exe" -replace "-")_") + @(($Devices.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

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
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port$Parameters$CommonParameters" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Ccminer"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 0.1 / 100}
                WarmupTime = 45
            }
        }
    }
}
