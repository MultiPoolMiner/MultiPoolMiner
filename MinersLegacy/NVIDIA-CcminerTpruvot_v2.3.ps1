using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "C3CD207D9EE15FBCB4C9BEEB20872E0B34D6E8A11D70026C98FDDB915E6CE8D4"
$Uri = "https://github.com/nemosminer/ccminerTpruvot/releases/download/v2.3-cuda10/ccminertpruvotx64.7z"
$Port = "40{0:d2}"

# Miner requires CUDA 10.0.00
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "10.0.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "allium"        = "" #Allium
    "bastion"       = "" #Bastion
    "bitcore"       = "" #Bitcore
    "bmw"           = "" #BMW
    "cryptolight"   = "" #CryptoNightLite
    #"c11/flax"     = "" #C11
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
    "lyra2z"        = "" #Lyra2z, ZCoin
    "neoscrypt"     = "" #NeoScrypt
    #"monero"        = "" # -> CryptoNightV7
    #"penta"         = "" #Pentablake - penta not in algorithms.txt
    "phi1612"       = "" #PHI, e.g. Seraph
    "phi2"          = "" #PHI2 LUX
    "polytimos"     = "" #Polytimos
    "scrypt-jane"   = "" #ScryptJaneNF
    "sha256t"       = "" #SHA256t
    #"skein"        = "" #Skein
    "skein2"        = "" #Skein2
    #"skunk"        = "" #Skunk
    #"sonoa"         = "" #97 hashes based on X17 ones (Sono) - sonoa not in algorithms.txt
    "stellite"      = "" #CryptoNightXtl
    "s3"            = "" #SHA256t
    "timetravel"    = "" #Timetravel
    "tribus"        = "" #Tribus
    "veltor"        = "" #Veltor
    "wildkeccak"    = "" #Boolberry
    #"whirlcoin"     = "" #Old Whirlcoin (Whirlpool algo) - whirlcoin not in algorithms.txt
    #"whirlpool"     = "" #WhirlPool
    #"whirlpoolx"    = "" #whirlpoolx
    "x11evo"        = "" #X11evo
    "x12"           = "" #X12
    "x16r"          = "" #X16R
    #"X16s"         = "" #X16S
    #"x17"          = "" #x17
    "zr5"           = "" #zr5

    # ASIC - never profitable 11/08/2018
    #"blake"        = "" #blake
    #"blakecoin"    = "" #Blakecoin
    #"blake2s"      = "" #Blake2s
    #"cryptonight"  = "" #CryptoNight
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
$CommonCommands = " --submit-stale"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_
        if ($_ -eq "monero") {$Algorithm_Norm = "CryptonightV7"} #temp fix, monero is a coin, not an algo; should mine CryptonightV7; monero algo is now CryptonightV8

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = <#temp fix#> Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "X16R"  {$BenchmarkIntervals = 5}
            default {$BenchmarkIntervals = 1}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Ccminer"
            Port               = $Miner_Port
            URI                = $Uri
            BenchmarkIntervals = $BenchmarkIntervals
        }
    }
}
