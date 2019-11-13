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

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA")

# Miner requires CUDA 10.0.00
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.0.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{ 
    #GPU - profitable 20/04/2018
    "Allium"         = " -a allium" #Allium
    "Bastion"        = " -a bastion" #Bastion
    "Bitcore"        = " -a bitcore" #Timetravel10 and Bitcore are technically the same
    "Blake2b"        = " -a blake2b" # new with 2.3.1
    "Bmw"            = " -a bmw" #BMW
    "C11/flax"       = " -a c11/flax" #C11
    "Deep"           = " -a deep" #Deep
    "Dmd-gr"         = " -a deep" #DMDGR
    #"Equihash"       = " -a equihash" #Equihash - Beaten by Bminer by 30%
    "EXosis"         = " -a exosis" #Exosis, new with 2.3 from Dec 02, 2018
    "Fresh"          = " -a fresh" #Fresh
    #"Fugue256"       = " -a fugue256" #Fugue256 - fugue256 not in algorithms.txt
    #"Graft"          = "" #CryptoNightV7
    "Hmq1725"        = " -a hmq1725" #HMQ1725
    "Jackpot"        = " -a jackpot" #JHA
    "Keccak"         = " -a keccak" #Keccak
    "Keccakc"        = " -a keccakc" #KeccakC
    "Luffa"          = " -a luffa" #Luffa
    "Lyra2v2"        = " -a lyra2v2" #Lyra2RE2
    "Lyra2v3"        = " -a lyra2v3" # new with 2.3.1
    "Lyra2z"         = " -a lyra2z" #Lyra2z, ZCoin
#    "Neoscrypt"      = " -a neoscrypt --intensity 22.2" #NeoScrypt, CcminerKlausT-v8.25 is faster
    "Penta"          = " -a penta" #Pentablake
    "Phi1612"        = " -a phi1612" #PHI, e.g. Seraph
    "Phi2"           = " -a phi2" #PHI2
    "Phi2-Lux"       = " -a phi2" #PHI2 LUX
    "Polytimos"      = " -a polytimos" #Polytimos
    "Scrypt-jane"    = " -a scrypt-jane" #ScryptJaneNF
    "Sha256q"        = " -a sha256q" # new with 2.3.1
    "Sha256t"        = " -a sha256t" #SHA256t
    #"Skein2"         = " -a skein2" #Skein2, NVIDIA-CcminerAlexis_v1.5 is faster
    "Skunk"          = " -a skunk" #Skunk
    "Sonoa"          = " -a sonoa" #97 hashes based on X17 ones (Sono)
    "CryptoNightXtl" = " -a stellite" #CryptoNightXtl
    "S3"             = " -a s3" #SHA256t
    "Timetravel"     = " -a timetravel" #Timetravel
    "Tribus"         = " -a tribus" #Tribus
    "Veltor"         = " -a veltor" #Veltor
    "Wildkeccak"     = " -a wildkeccak" #Boolberry
    "Whirlcoin"      = " -a whirlcoin" #Old Whirlcoin (Whirlpool algo)
    "whirlpool"      = " -a whirlpool" #WhirlPool
    "Whirlpoolx"     = " -a whirlpoolx" #whirlpoolx
    #"X11evo"         = " -a x11evo" #X11evo; CcminerAlexis_v1.5 is faster
    "X12"            = " -a x12 -i 21" #X12
    #"X16r"           = " -a x16r" #X16R; Other free miners are faster
    #"X16s"          = " -a X16s" #X16S
    #"x17"           = " -a x17" #x17
    "Zr5"            = " -a zr5" #zr5

    # ASIC - never profitable 28/08/2019
    #"Blake"         = " -a blake" #blake
    #"Blakecoin"     = " -a blakecoin" #Blakecoin
    #"Blake2s"       = " -a blake2s" #Blake2s
    #"CryptonightV1"  = " -a monero" # -> CryptonightV1
    #"Cryptolight"   = " -a cryptolight" #CryptonightLite
    #"Cryptonight"   = " -a cryptonight" #Cryptonight
    #"Groestl"       = " -a groestl" #Groestl
    #"Lbry"          = " -a lbry" #Lbry
    #"Lyra2"         = " -a lyra2" #Lyra2RE
    #"Decred"        = " -a decred" #Decred
    #"Quark"         = " -a quark" #Quark
    #"Qubit"         = " -a qubit" #Qubit
    #"Myr-gr"        = " -a "myr-gr" #MyriadGroestl
    #"Nist5"         = " -a nist5" #Nist5
    #"Scrypt"        = " -a scrypt" #Scrypt
    #"Scrypt:N"      = " -a scrypt:N" #scrypt:N
    #"Sha256d"       = " -a sha256d" #sha256d
    #"Sia"           = " -a sia" #SiaCoin
    #"Sib"           = " -a sib" #Sib
    #"Skein"         = " -a skein" #Skein
    #"Vanilla"       = " -a vanilla" #BlakeVanilla
    #"X11"           = " -a x11" #X11
    #"X13"           = " -a x13" #x13
    #"X14"           = " -a x14" #x14
    #"X15"           = " -a x15" #x15
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " --submit-stale" }

$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { if ($_ -eq "monero") { $Algorithm_Norm = "cryptonight7" }<#TempFix, monero is no longer using cn7#> else  { $Algorithm_Norm = Get-Algorithm $_ }; $_ } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> } | ForEach-Object { 
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{ 
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
