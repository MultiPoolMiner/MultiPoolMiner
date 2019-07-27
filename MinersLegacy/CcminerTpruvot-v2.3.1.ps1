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

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        #GPU - profitable 20/04/2018
        "allium"        = "" #Allium
        "bastion"       = "" #Bastion
        "bitcore"       = "" #Timetravel10 and Bitcore are technically the same
        "blake2b"       = "" # new with 2.3.1
        "bmw"           = "" #BMW
        "cryptolight"   = "" #CryptonightLite
        "c11/flax"      = "" #C11
        "deep"          = "" #Deep
        "dmd-gr"        = "" #DMDGR
        #"equihash"     = "" #Equihash - Beaten by Bminer by 30%
        "exosis"        = "" #Exosis, new with 2.3 from Dec 02, 2018
        "fresh"         = "" #Fresh
        #"fugue256"      = "" #Fugue256 - fugue256 not in algorithms.txt
        #"graft"         = "" #CryptoNightV7
        "hmq1725"       = "" #HMQ1725
        "jackpot"       = "" #JHA
        "keccak"        = "" #Keccak
        "keccakc"       = "" #KeccakC
        "luffa"         = "" #Luffa
        "lyra2v2"       = "" #Lyra2RE2
        "lyra2v3"       = "" # new with 2.3.1
        "lyra2z"        = "" #Lyra2z, ZCoin
        "neoscrypt"     = "" #NeoScrypt
        "monero"        = "" # -> CryptonightV7
        #"penta"         = "" #Pentablake - penta not in algorithms.txt
        "phi1612"       = "" #PHI, e.g. Seraph
        "phi2"          = "" #PHI2 LUX
        "polytimos"     = "" #Polytimos
        "scrypt-jane"   = "" #ScryptJaneNF
        "sha256q"       = "" # new with 2.3.1
        "sha256t"       = "" #SHA256t
        #"skein"        = "" #Skein
        #"skein2"        = "" #Skein2, NVIDIA-CcminerAlexis_v1.5 is faster
        #"skunk"        = "" #Skunk
        #"sonoa"         = "" #97 hashes based on X17 ones (Sono)
        "stellite"      = "" #CryptoNightXtl
        "s3"            = "" #SHA256t
        "timetravel"    = "" #Timetravel
        "tribus"        = "" #Tribus
        "veltor"        = "" #Veltor
        "wildkeccak"    = "" #Boolberry
        #"whirlcoin"     = "" #Old Whirlcoin (Whirlpool algo) - whirlcoin not in algorithms.txt
        #"whirlpool"     = "" #WhirlPool
        #"whirlpoolx"    = "" #whirlpoolx
      # "x11evo"        = "" #X11evo; CcminerAlexis_v1.5 is faster
        "x12"           = "" #X12
      # "x16r"          = "" #X16R; Other free miners are faster
        #"X16s"         = "" #X16S
        #"x17"          = "" #x17
        "zr5"           = "" #zr5

        # ASIC - never profitable 11/08/2018
        #"blake"        = "" #blake
        #"blakecoin"    = "" #Blakecoin
        #"blake2s"      = "" #Blake2s
        #"cryptonight"  = "" #Cryptonight
        #"groestl"      = "" #Groestl
        #"lbry"         = "" #Lbry
        #"lyra2"        = "" #Lyra2RE
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
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --submit-stale"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {if ($_ -eq "monero") {$Algorithm_Norm = "cryptonight7"}<#TempFix, monero is no longer using cn7#> else  {$Algorithm_Norm = Get-Algorithm $_}; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

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

        Switch ($Algorithm_Norm) {
            "X16R"  {$IntervalMultiplier = 5}
            default {$IntervalMultiplier = 1}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            BaseName           = $Miner_BaseName
            Version            = $Miner_Version
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Ccminer"
            Port               = $Miner_Port
            URI                = $Uri
            IntervalMultiplier = $IntervalMultiplier
        }
    }
}
