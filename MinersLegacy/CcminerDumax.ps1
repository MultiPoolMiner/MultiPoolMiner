using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-CcminerDumax\ccminer.exe"
$HashSHA256 = "C1E656D883FAE8EE7F01656EFFC3570FA27FCC8E01515D23F44616A1CDEC93F7"
$Uri = "https://github.com/DumaxFr/ccminer/releases/download/dumax-0.9.4/ccminer-dumax-0.9.4-win64.zip"
$ManualUri = "https://github.com/DumaxFr/ccminer/releases"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "phi"   = "" #PHI
    "phi2"  = "" #PHI2
    "x16r"  = "" #X16r
    "x16s"  = "" #X16s
    "x17"   = "" #x17
}

$CommonCommands = " --submit-stale"

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

        Switch ($Algorithm_Norm) {
            "PHI2"   {$ExtendInterval = 3}
            "X16R"  {$ExtendInterval = 10}
            "X16S"  {$ExtendInterval = 10}
            default {$ExtendInterval = 0}
        }

        [PSCustomObject]@{
            Name           = $Miner_Name
            DeviceName     = $Miner_Device.Name
            Path           = $Path
            HashSHA256     = $HashSHA256
            Arguments      = ("-R 1 -q -a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API            = "Ccminer"
            Port           = $Miner_Port
            URI            = $Uri
            ExtendInterval = $ExtendInterval
        }
    }
}
