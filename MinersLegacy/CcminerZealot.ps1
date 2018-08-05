using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-CcminerZealot\z-enemy.exe"
$HashSHA256 = "02A2B37372FD2C81AFFBA29C5764A591ED5351E40FAD809C431BC39FF7DB0A98"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Zenemy/z-enemy.1-14-cuda9.2_x64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "aergo"      = "" #AeriumX, new in 1.11
    "bitcore"    = "" #Bitcore
    "c11"        = "" #C11, new in 1.11
    "hsr"        = "" #Hsr
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

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"

# Miner requires CUDA 9.2
$DriverVersion = (Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and $DriverVersion -lt $RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        Switch ($Algorithm_Norm) {
        	"PHI"   {$ExtendInterval = 3}
        	"PHI2"  {$ExtendInterval = 3}
        	"X16R"  {$ExtendInterval = 10}
        	"X16S"  {$ExtendInterval = 10}
        	default {$ExtendInterval = 0}
        }

        [PSCustomObject]@{
            Name             = $Miner_Name
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API              = "Ccminer"
            Port             = $Miner_Port
            URI              = $Uri
            Fees             = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            ExtendInterval   = $ExtendInterval
        }
    } 
}
