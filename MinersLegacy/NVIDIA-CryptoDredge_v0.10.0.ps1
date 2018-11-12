using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\CryptoDredge.exe"
$ManualUri = "https://github.com/technobyl/CryptoDredge"
$Port = "40{0:d2}"

# Miner requires CUDA 9.2 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

if ($DriverVersion -lt [System.Version]("10.0.0")) {
    $Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.10.0/CryptoDredge_0.10.0_cuda_9.2_windows.zip"
    $HashSHA256 = "216EE4908E5BBEFC375090FEAC6EF0D3E028403F7FFCFB922818998A74CB81B0"
}
else {
    $Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.10.0/CryptoDredge_0.10.0_cuda_10.0_windows.zip"
    $HashSHA256 = "6964F0D3F62BBC3F4C8F6D09B574B49447312417B102E0ACF8398A06DB93A6FF"
}
                   
$Commands = [PSCustomObject]@{
    "aeon"      = "" #Aeon, new in 0.9 (CryptoNight-Lite algorithm)
    "allium"    = "" #Allium
    "bitcore"   = "" #BitCore, new in 0.9.5
    "blake2s"   = "" #Blake2s, new in 0.9
    "bcd"       = "" #BitcoinDiamond, new in 0.9.4
    "c11"       = "" #C11, new in 0.9.4
    "cnheavy"   = " -i 5" #CryptoNightHeavy, new in 0.9
    "cnhaven"   = " -i 5" #CryptoNightHeavyHaven, new in 0.9.1
    "cnv7"      = " -i 5" #CyptoNightV7, new in 0.9
    "cnv8"      = " -i 5" #CyptoNightV9, new in 0.9.3
    "cnfast"    = " -i 5" #CryptoNightFast, new in 0.9
    "cnsaber"   = " -i 5" #CryptonightHeavyTube (BitTube), new in 0.9.2
    "exosis"    = "" #Exosis, new in 0.9.4
    "hmq1725"   = "" #HMQ1725, new in 0.10.0
    "lbk3"      = "" #used by Vertical VTL, new with 0.9.0
    "lyra2v2"   = "" #Lyra2REv2
    "lyra2z"    = "" #Lyra2z
    "neoscrypt" = "" #NeoScrypt
    "phi"       = "" #PHI
    "phi2"      = "" #PHI2
    "polytimos" = "" #Polytimos, new in 0.9.4
    "skein"     = "" #Skein
    "skunkhash" = "" #Skunk
    "stellite"  = " -i 5" #CryptoNightXtl, new in 0.9
    "tribus"    = "" #Tribus, new with 0.8
    "x17"       = "" #X17, new in 0.9.5
    "x22i"      = "" #X22i, new in 0.9.6
}
$CommonCommands = " --no-watchdog --no-color"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = "$Name-$($Miner_Device.count)x$($Miner_Device.Model_Norm | Sort-Object -unique)"
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        [PSCustomObject]@{
            Name             = $Miner_Name
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = ("--api-type ccminer-tcp --api-bind 127.0.0.1:$($Miner_Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API              = "Ccminer"
            Port             = $Miner_Port
            URI              = $Uri
            Fees             = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
        }
    }
}
