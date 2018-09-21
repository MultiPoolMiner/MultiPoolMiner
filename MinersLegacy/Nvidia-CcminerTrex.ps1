using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-CcminerTrex\t-rex.exe"
$HashSHA256 = "499A25FAA5DF87C8353AEB707C1514E74F22A3BE2508075D08830013B5FECF6F"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/T-rex/t-rex-0.6.6-win-cuda9.1.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4432704.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "balloon"   = "" #Balloon, New in 0.6.2
    "bcd"       = "" #BitcoinDiamond, New in 0.6.5
    "bitcore"   = "" #Bitcore, New in 0.6.1
    "c11"       = "" #C11
    "hsr"       = "" #HSR
    "hmq1725"   = "" #Hmq1725, New in 0.6.4
    "lyra2z"    = "" #Lyra2z
    "phi"       = "" #Phi
    "polytimos" = "" #Polytimos, New in 0.6.3
    "renesis"   = "" #Renesis
    "skunk"     = "" #Skunk, New in 0.6.3
    "sonoa"     = "" #Sonoa, New in 0.6.1
    "tribus"    = "" #Tribus
    "x16r"      = "" #X16r
    "x16s"      = "" #X16s
    "x17"       = "" #x17
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
            "X16R"  {$ExtendInterval = 10}
            default {$ExtendInterval = 0}
        }

        [PSCustomObject]@{
            Name           = $Miner_Name
            DeviceName     = $Miner_Device.Name
            Path           = $Path
            HashSHA256     = $HashSHA256
            Arguments      = ("-b 127.0.0.1:$($Miner_Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API            = "Ccminer"
            Port           = $Miner_Port
            URI            = $Uri
            Fees           = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
            ExtendInterval = $ExtendInterval
        }
    }
}
