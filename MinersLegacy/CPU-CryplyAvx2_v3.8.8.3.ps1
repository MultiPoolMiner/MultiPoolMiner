using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\CPU-Cryply_v3.8.8.3\cpuminer-avx2.exe"
$HashSHA256 = "89384FB35DA4D6FE75449020FE7A4FEC2BD8EB8FD26CCFB5E1980B93BD29578E"
$Uri = "https://github.com/bubasik/cpuminer-opt-yespower/releases/download/v3.8.8.3/cpuminer-opt-cryply-yespower-ver2.zip"
$ManualUri = "https://github.com/bubasik/cpuminer-opt-yespower/releases"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    ### CPU PROFITABLE ALGOS AS OF 25/07/2018
    ### these algorithms are profitable algorithms on supported pools
    "allium"        = "" #Garlicoin (GRLC)
    "cryptonightv7" = "" #variant 7, Monero (XMR)
    "hmq1725"       = "" #Espers
    "hodl"          = "" #Hodlcoin
    "lyra2z"        = "" #Zcoin (XZC)
    "m7m"           = "" #Magi (XMG)
    "x12"           = "" #Galaxie Cash (GCH)
    "yescrypt"      = "" #Globlboost-Y (BSTY)
    "yescryptr16"   = "" #Yenten (YTN)

    ### MAYBE PROFITABLE ALGORITHMS - NOT MINEABLE IN SUPPORTED POOLS AS OF 25/07/2018
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

    #GPU or ASIC - never profitable 25/07/2018
    #"blake"         = "" #blake256r14 (SFR)
    #"blakecoin"     = "" #blake256r8
    #"blake2s"       = "" #Blake-2 S
    #"cryptolight"   = "" #Cryptonight-light
    #"cryptonight"   = "" #Cryptonote legacy
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
    #"timetravel"    = "" #timeravel8, Machinecoin (MAC)
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
$CommonCommands = ""

$Devices = $Devices | Where-Object Type -EQ "CPU"  | Where-Object {(-not $_.CpuFeatures) -or ($_.CpuFeatures -contains "avx2")}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port$($Commands.$_)$($CommonCommands)" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{$Algorithm_Norm = 0.1 / 100}
        }
    }
}
