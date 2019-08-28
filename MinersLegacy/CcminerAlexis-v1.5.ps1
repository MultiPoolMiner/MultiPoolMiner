using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "EF54D9CC26C7B2A5C153B67DE48896E368F4CCC0A3F38AA14FB55E71828D7360"
$Uri = "https://github.com/nemosminer/ccminerAlexis78/releases/download/Alexis78-v1.5/ccminerAlexis78v1.5.7z"
$ManualUri = "https://github.com/nemosminer/ccminerAlexis78"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 10.1.00
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.1.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{
    #GPU - profitable 16/05/2018
    #Intensities and parameters tested by nemosminer on 10603gb to 1080ti
    "C11"          = " -a c11 -i 22.1" #X11evo; fix for default intensity
    "Hsr"          = " -a hsr" #HSR, HShare
    "Keccak"       = " -a keccak -m 2 -i 29" #Keccak; fix for default intensity, difficulty x M
    "KeccakC"      = " -a keccakc -i 29" #Keccakc; fix for default intensity
    "Lyra2v2"      = " -a lyra2v2" #lyra2v2
    #"Neoscrypt"   = " -a neoscrypt -i 15.5" #NeoScrypt, CcminerKlausT-v8.25 is faster
    "Polytimos"    = " -a poly -i 21" #Poly
    "Skein"        = " -a skein" #Skein
    "Skein2"       = " -a skein2 -i 31" #skein2
    "Veltor"       = " -a veltor -i 23" #Veltor; fix for default intensity
    "Whirlcoin"    = " -a whirlcoin" #WhirlCoin
    "Whirlpool"    = " -a whirlpool" #Whirlpool
    "X11evo"       = " -a x11evo -i 21" #X11evo; fix for default intensity
    "X17"          = " -a x17 -i 22.1" #x17; fix for default intensity

    # ASIC - never profitable 11/08/2018
    #"Blake2s"     = " -a blake2s" #Blake2s
    #"Blake"       = " -a blake" #blake
    #"Blakecoin"   = " -a blakecoin" #Blakecoin
    #"Cryptolight" = " -a cryptonight" #cryptolight
    #"Cryptonight" = " -a cryptolight" #CryptoNight
    #"Decred"      = " -a decred" #Decred
    #"Lbry"        = " -a lbry" #Lbry
    #"Lyra2"       = " -a lyra2" #Lyra2
    #"Myr-gr"      = " -a myr-gr" #MyriadGroestl
    #"Nist5"       = " -a nist5" #Nist5
    #"Quark"       = " -a quark" #Quark
    #"Qubit"       = " -a qubit" #Qubit
    #"Scrypt"      = " -a scrypt" #Scrypt
    #"Scrypt:N"    = " -a scrypt:n" #scrypt:N
    #"Sha256d"     = " -a sha256d" #sha256d
    #"Sia"         = " -a sia" #SiaCoin
    #"Sib"         = " -a sib" #Sib
    #"X11"         = " -a x11" #X11
    #"X13"         = " -a x13" #x13
    #"X14"         = " -a x14" #x14
    #"X15"         = " -a x15" #x15
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --cuda-schedule 2 -N 1"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1
        
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

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
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
