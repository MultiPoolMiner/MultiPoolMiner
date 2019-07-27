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

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        #GPU - profitable 16/05/2018
        #Intensities and parameters tested by nemosminer on 10603gb to 1080ti
        "c11"          = " -i 21" #X11evo; fix for default intensity
        "hsr"          = "" #HSR, HShare
        "keccak"       = " -m 2 -i 29" #Keccak; fix for default intensity, difficulty x M
        "keccakc"      = " -i 29" #Keccakc; fix for default intensity
        "lyra2v2"      = "" #lyra2v2
        #"neoscrypt"   = " -i 15.5" #NeoScrypt; fix for default intensity, about 50% slower then Excavator or JustAMinerNeoScrypt 
        "poly"         = "" #Poly
        "skein"        = "" #Skein
        "skein2"       = "" #skein2
        "veltor"       = " -i 23" #Veltor; fix for default intensity
        "whirlcoin"    = "" #WhirlCoin
        "whirlpool"    = "" #Whirlpool
        "x11evo"       = " -i 21" #X11evo; fix for default intensity
        "x17"          = " -i 20" #x17; fix for default intensity

        # ASIC - never profitable 11/08/2018
        #"blake2s"     = "" #Blake2s
        #"blake"       = "" #blake
        #"blakecoin"   = "" #Blakecoin
        #"cryptolight" = "" #cryptolight
        #"cryptonight" = "" #CryptoNight
        #"decred"      = "" #Decred
        #"lbry"        = "" #Lbry
        #"lyra2"       = "" #Lyra2
        #"myr-gr"      = "" #MyriadGroestl
        #"nist5"       = "" #Nist5
        #"quark"       = "" #Quark
        #"qubit"       = "" #Qubit
        #"scrypt"      = "" #Scrypt
        #"scrypt:N"    = "" #scrypt:N
        #"sha256d"     = "" #sha256d
        #"sia"         = "" #SiaCoin
        #"sib"         = "" #Sib
        #"x11"         = "" #X11
        #"x13"         = "" #x13
        #"x14"         = "" #x14
        #"x15"         = "" #x15
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --cuda-schedule 2 -N 1"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1
        
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
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

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
