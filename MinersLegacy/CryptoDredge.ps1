using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge.exe"
$HashSHA256 = "A921645B0C07225CCEF21D833B3E9EB765FEDD48F48A1D0BB7E22C7B4FE30ACA"
$Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.8.0/CryptoDredge_0.8.0_cuda_9.2_windows.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"
$Port = "60{0:d2}"

$Commands = [PSCustomObject]@{
    "allium"    = "" #Allium
    "lyra2v2"   = "" #Lyra2REv2
    "lyra2z"    = "" #Lyra2z
    "neoscrypt" = "" #NeoScrypt
    "phi"       = "" #PHI
    "phi2"      = "" #PHI2
    "skein"     = "" #Skein
    "skunkhash" = "" #Skunk
    "tribus"    = "" #Tribus, new with 0.8
}
$CommonCommands = " --no-watchdog --no-color"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Miner requires CUDA 9.2
$DriverVersion = (Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and $DriverVersion -lt $RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object -ExpandProperty Model | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

        Switch ($Algorithm_Norm) {
            "PHI"     {$ExtendInterval = 3}
            "PHI2"    {$ExtendInterval = 3}
            default   {$ExtendInterval = 0}
        }

        [PSCustomObject]@{
            Name           = $Miner_Name
            DeviceName     = $Miner_Device.Name
            Path           = $Path
            HashSHA256     = $HashSHA256
            Arguments      = "--api-type ccminer-tcp --api-bind 127.0.0.1:$($Miner_Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')"
            HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API            = "Ccminer"
            Port           = $Miner_Port
            URI            = $Uri
            Fees           = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
            ExtendInterval = $ExtendInterval
        }
    }
}
