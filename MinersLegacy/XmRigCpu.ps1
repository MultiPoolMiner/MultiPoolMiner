using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\CPU-XmRig-Cryptonight\xmrig.exe"
$HashSHA256 = "EA2E92BB10D0482880F8D389B7915948E11F672CA8559B0901D8A8FA8E9D733E"
$Uri = "https://github.com/xmrig/xmrig/releases/download/v2.6.4/xmrig-2.6.4-msvc-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig-cpu"
$Port = "339{0:d1}"

$Commands = [PSCustomObject]@{
    "cryptonight/1"          = "" #CryptoNightV7; Also known as monero7 and CryptoNightV7
    "cryptonight/xtl"        = "" #CryptoNightXtl; Stellite (XTL)
    "cryptonight/msr"        = "" #CryptoNightFast; also known as cryptonight-masari (MSR)
    "cryptonight/xao"        = "" #CryptoNightAlloy (XAO)
    "cryptonight/rto"        = "" #CryptoNightArto (RTO)
    "cryptonight-lite"       = "" #CryptoNightLite; Autodetect works only for Aeon
    "cryptonight-lite/0"     = "" #CryptoNightLite; Original/old CryptoNight-Lite
    "cryptonight-lite/1"     = "" #CryptoNightLiteV7; also known as aeon7
    "cryptonight-heavy"      = "" #CryptoNightHeavy; Ryo and Loki
    "cryptonight-heavy/xhv"  = "" #CryptoNightHaven Protocol
    "cryptonight-heavy/tube" = "" #CryptoNightHeavyTube (TUBE)

    # ASIC only (09/07/2018)
    #"cryptonight"            = ""} #Autodetect works only for Monero
    #"cryptonight"            = ""} #Original/old CryptoNight
}
$CommonCommands = ""

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = @($Devices | Where-Object Type -EQ "CPU")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = "--api-port $($Miner_Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --keepalive --nicehash --rig-id=$($Worker) --donate-level 1$($Commands.$_)$CommonCommands"
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "XmRig"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
        }
    }
}
