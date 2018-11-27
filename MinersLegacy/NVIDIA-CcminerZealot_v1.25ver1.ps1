using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\z-enemy.exe"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"
$Port = "40{0:d2}"

# Miner requires CUDA 9.2.00 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

if ($DriverVersion -lt [System.Version]("10.0.0")) {
    $HashSHA256 = "CE01A93D426E1A6F55045B4E012F863D68A3D12C9CEEAA0955D331E951439276"
    $Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Zenemy/z-enemy.1-25-cuda_9.2_ver1.zip"
}
else {
    $HashSHA256 = "11217EFE543AA84A143280107C15AD13C4F058C4F72A0EEFD3736008D33FB1C8"
    $Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Zenemy/z-enemy.1-25-cuda10.0_ver1.zip"
}

$Commands = [PSCustomObject]@{
    "aergo"      = "" #Aergo, new in 1.11
    "bitcore"    = "" #Bitcore
    "bcd"        = "" #Bitcoin Diamond, new in 1.20
    "c11"        = "" #C11, new in 1.11
    "hex"        = "" #Hex
    "phi"        = "" #PHI
    "phi2"       = "" #Phi2
    "poly"       = "" #Polytimos
    "renesis"    = "" #Renesis
    "skunk"      = "" #Skunk, new in 1.11
    "sonoa"      = "" #SONOA, new in 1.12
    "timetravel" = "" #Timetravel8
    "tribus"     = "" #Tribus, new in 1.10
    "x16r"       = " -N 100" #Raven, number of samples used to compute hashrate (default: 30) 
    "x16s"       = "" #Pigeon
    "x17"        = "" #X17
    "xevan"      = "" #Xevan, new in 1.09a
}
$CommonCommands = ""

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

        #Get commands for active miner devices
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

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
            Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            BenchmarkIntervals = $BenchmarkIntervals
        }
    } 
}
