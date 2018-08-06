using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-CcminerTrex\t-rex.exe"
$HashSHA256 = "4DE665A6B81676F2D56B0F5B25497FB19D69341AC3338F8CC9E6F04B802379E3"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/T-rex/t-rex-0.5.7-win-cuda9.1.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4432704.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "c11"           = "" #C11
    "hsr"           = "" #HSR
    "lyra2z"        = "" #Lyra2z
    "phi"           = "" 
    "phi2"          = "" #LUX
    "renesis"       = "" #Renesis
    "tribus"        = "" #Tribus
    "x16r"          = "" #X16r
    "x16s"          = "" #X16s
    "x17"           = "" #x17
}

$CommonCommands = ""

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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
            Name           = $Miner_Name
            DeviceName     = $Miner_Device.Name
            Path           = $Path
            HashSHA256     = $HashSHA256
            Arguments      = ("-b 127.0.0.1:$($Miner_Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API            = "Ccminer"
            Port           = $Miner_Port
            URI            = $Uri
            Fees           = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
            ExtendInterval = $ExtendInterval
        }
    }
}
