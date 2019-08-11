using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer-x64.exe"
$HashSHA256 = "D82269A66F8495FC5113EA6B333B45EC5A282BE0E148DB956D3660E3AAB919B1"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.3.1-tpruvot/ccminer-2.3.1-cuda10.7z"
$ManualUri = "https://github.com/tpruvot/ccminer"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 10.0.00
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.0.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "allium"        = " -a allium" #Allium
    "bastion"       = " -a bastion" #Bastion
    "bitcore"       = " -a bitcore" #Timetravel10 and Bitcore are technically the same
    "blake2b"       = " -a blake2b" # new with 2.3.1
    "bmw"           = " -a bmw" #BMW
    "cryptolight"   = " -a cryptolight" #CryptonightLite
    "c11/flax"      = " -a c11/flax" #C11
    "deep"          = " -a deep" #Deep
    "dmd-gr"        = " -a deep" #DMDGR
    #"equihash"      = " -a equihash" #Equihash - Beaten by Bminer by 30%
    "exosis"        = " -a exosis" #Exosis, new with 2.3 from Dec 02, 2018
    "fresh"         = " -a fresh" #Fresh
    #"fugue256"      = " -a fugue256" #Fugue256 - fugue256 not in algorithms.txt
    #"graft"         = "" #CryptoNightV7
    "hmq1725"       = " -a graft" #HMQ1725
    "jackpot"       = " -a jackpot" #JHA
    "keccak"        = " -a keccak" #Keccak
    "keccakc"       = " -a keccakc" #KeccakC
    "luffa"         = " -a luffa" #Luffa
    "lyra2v2"       = " -a lyra2v2" #Lyra2RE2
    "lyra2v3"       = " -a lyra2v3" # new with 2.3.1
    "lyra2z"        = " -a lyra2z" #Lyra2z, ZCoin
    "neoscrypt"     = " -a neoscrypt" #NeoScrypt
    "monero"        = " -a monero" # -> CryptonightV7
    "penta"         = " -a penta" #Pentablake
    "phi1612"       = " -a phi1612" #PHI, e.g. Seraph
    "phi2"          = " -a phi2" #PHI2 LUX
    "polytimos"     = " -a polytimos" #Polytimos
    "scrypt-jane"   = " -a scrypt-jane" #ScryptJaneNF
    "sha256q"       = " -a sha256q" # new with 2.3.1
    "sha256t"       = " -a sha256t" #SHA256t
    #"skein2"        = " -a skein2" #Skein2, NVIDIA-CcminerAlexis_v1.5 is faster
    "skunk"         = " -a skunk" #Skunk
    "sonoa"         = " -a sonoa" #97 hashes based on X17 ones (Sono)
    "stellite"      = " -a stellite" #CryptoNightXtl
    "s3"            = " -a s3" #SHA256t
    "timetravel"    = " -a timetravel" #Timetravel
    "tribus"        = " -a tribus" #Tribus
    "veltor"        = " -a veltor" #Veltor
    "wildkeccak"    = " -a wildkeccak" #Boolberry
    "whirlcoin"     = " -a whirlcoin" #Old Whirlcoin (Whirlpool algo)
    "whirlpool"     = " -a whirlpool" #WhirlPool
    "whirlpoolx"    = " -a whirlpoolx" #whirlpoolx
    #"x11evo"        = " -a x11evo" #X11evo; CcminerAlexis_v1.5 is faster
    "x12"           = " -a x12" #X12
    #"x16r"          = " -a x16r" #X16R; Other free miners are faster
    #"X16s"         = " -a X16s" #X16S
    #"x17"          = " -a x17" #x17
    "zr5"           = " -a zr5" #zr5

    # ASIC - never profitable 06/08/2019
    #"blake"        = " -a blake" #blake
    #"blakecoin"    = " -a blakecoin" #Blakecoin
    #"blake2s"      = " -a blake2s" #Blake2s
    #"cryptonight"  = " -a cryptonight" #Cryptonight
    #"groestl"      = " -a groestl" #Groestl
    #"lbry"         = " -a lbry" #Lbry
    #"lyra2"        = " -a lyra2" #Lyra2RE
    #"decred"       = " -a decred" #Decred
    #"quark"        = " -a quark" #Quark
    #"qubit"        = " -a qubit" #Qubit
    #"myr-gr"       = " -a "myr-gr" #MyriadGroestl
    #"nist5"        = " -a nist5" #Nist5
    #"scrypt"       = " -a scrypt" #Scrypt
    #"scrypt:N"     = " -a scrypt:N" #scrypt:N
    #"sha256d"      = " -a sha256d" #sha256d
    #"sia"          = " -a sia" #SiaCoin
    #"sib"          = " -a sib" #Sib
    #"skein"        = " -a skein" #Skein
    #"vanilla"      = " -a vanilla" #BlakeVanilla
    #"x11"          = " -a x11" #X11
    #"x13"          = " -a x13" #x13
    #"x14"          = " -a x14" #x14
    #"x15"          = " -a x15" #x15
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --submit-stale"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {if ($_ -eq "monero") {$Algorithm_Norm = "cryptonight7"}<#TempFix, monero is no longer using cn7#> else  {$Algorithm_Norm = Get-Algorithm $_}; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
