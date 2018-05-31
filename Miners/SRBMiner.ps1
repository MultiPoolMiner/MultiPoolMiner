using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\AMD-SRBMiner\SRBMiner-CN.exe"
$HashSHA256 = "5B688A918F3E67E552A31B2D1A20B6E3F0D4683116EA07EC9C1817F135CDEC9C"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/SRBMiner/SRBMiner-CN-V1-5-6.zip"
$UriManual = "https://bitcointalk.org/index.php?topic=3167363.0"
$MinerFeeInPercent = 0.85

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Type = "AMD"
$Port = 21555
$API = "SRBMiner"
                
if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
    $Fees = @($null)
}
else {
    $Fees = @($MinerFeeInPercent)
}

# Commands are case sensitive!
$Commands = [PSCustomObject]@{
    # Note: For fine tuning directly edit [AlgorithmName]_config.txt in the miner binary 
    "alloy"           = "" # CryptoNight-Alloy
    "artocash"        = "" # CryptoNight-ArtoCash
    "b2n"             = "" # CryptoNight-B2N
    "lite"            = "" # CryptoNight-Lite
    "liteV7"          = "" # CryptoNight-Lite V7
    "heavy"           = "" # CryptoNight-Heavy
    "ipbc"            = "" # CryptoNight-Ipbc
    "marketcash"      = "" # CryptoNight-MarketCash
    "normalv7"        = "" # CryptoNightV7
    #"normal"         = "" # CryptoNight is ASIC territory
    "alloy:2"         = "" # CryptoNight-Alloy double threads
    "artocash2"       = "" # CryptoNight-ArtoCash double threads
    "b2n:2"           = "" # CryptoNight-B2N double threads
    "lite:2"          = "" # CryptoNight-Lite double threads
    "liteV7:2"        = "" # CryptoNight-Lite V7 double threads
    "heavy:2"         = "" # CryptoNight-Heavy double threads
    "ipbc:2"          = "" # CryptoNight-Ipbc double threads
    "marketcash:2"    = "" # CryptoNight-MarketCash double threads
    "normalv7:2"      = "" # CryptoNightV7
}
$CommonCommands = ""

# Get array of IDs of all devices in device set, returned DeviceIDs are of base $DeviceIdBase representation starting from $DeviceIdOffset
$DeviceIDsSet = Get-DeviceIDs -Config $Config -Devices $Devices -Type $Type -DeviceTypeModel $($Devices.$Type) -DeviceIdBase 16 -DeviceIdOffset 0

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.$(Get-Algorithm "cryptonight-$($_ -split(":") | Select-Object -Index 0)")} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm "cryptonight-$($_ -split(":") | Select-Object -Index 0)"
    $Miner_Name = "$Name$($_ -split(":") | Select-Object -Index 1)"
    
    $HashRate = $Stats."$Miner_Name".Week
    if ($Fees) {$HashRate = $HashRate * (1 - $MinerFeeInPercent / 100)}
    
    $ConfigFile = "Config-$($_ -replace ":2", "-DoubleThreads").txt"
  
    ([PSCustomObject]@{
            api_enabled      = $true
            api_port         = $Port
            api_rig_name     = "$($Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker)"
            cryptonight_type = ($_ -split(":") | Select-Object -Index 0)
            double_threads   = (($_ -split(":") | Select-Object -Index 1) -eq "2")
        } | ConvertTo-Json -Depth 10
    ) | Set-Content "$(Split-Path $Path)\$($ConfigFile)" -ErrorAction Ignore

    [PSCustomObject]@{
        Name       = $Miner_Name
        Type       = "AMD"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "--config $ConfigFile --cpool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --cwallet $($Pools.$Algorithm_Norm.User) --cpassword $($Pools.$Algorithm_Norm.Pass) --ctls $($Pools.$Algorithm_Norm.SSL) --cnicehash $($Pools.$Algorithm_Norm.Name -eq 'NiceHash')$Command.$_$CommonCommands"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = $Api
        Port       = $Port
        URI        = $Uri
        Fees       = $Fees
    }
}