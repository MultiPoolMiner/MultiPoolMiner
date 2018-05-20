using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)


$Type = "AMD"
if (-not ($Devices.$Type -or $Config.InfoOnly)) {return} # No AMD mining device present in system, InfoOnly is for Get-Binaries

$Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega.exe"
$API = "XMRig"
$HashSHA256 = "5AF6A8F1EA7F5D512CA4E70F0436C33DD961BCDCDDDFFA52F9306404557379A9"
$Uri = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_100.zip"
$Port = 7777
$Fees = 1.5

$Commands = [PSCustomObject]@{
    "CryptoNight"          = @("0","") #CryptoNight, first item is algo number, second for additional miner commands
    "CryptoNightV7"        = @("1","") #CryptoNightV7
    "CryptoNight-Heavy"    = @("2","") #CryptoNight-Heavy
    "CryptoNightLite"      = @("3","") #CryptoNightLite
    "cryptonight-litev7"   = @("4","") #CryptoNightLitetV7
    "CryptoNightIPBC-Lite" = @("5","") #CryptoNightIPBC-Lite
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
    $Fees = @($null)
}
else {
    $Fees = @($MinerFeeInPercent)
}

# Get array of IDs of all devices in device set, returned DeviceIDs are of base $DeviceIdBase representation starting from $DeviceIdOffset
$DeviceIDs = (Get-DeviceIDs -Config $Config -Devices $Devices -Type $Type -DeviceTypeModel $($Devices.$Type) -DeviceIdBase 16 -DeviceIdOffset 0)."All"

$Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_
    
    if ($Pools.$Algorithm_Norm) { # must have a valid pool to mine

        $HashRate = ($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)
		
        if ($Fees) {$HashRate = $HashRate * (1 - $MinerFeeInPercent / 100)}
		
        [PSCustomObject]@{
            Name       = $Name
            Type       = $Type
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("--remoteaccess -a $($Commands.$_ | Select-Object -Index 0) -S $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --forcecompute --fastjobswitch -G $($DeviceIDs -join ',')$($Commands.$_ | Select-Object -Index 1)")
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
            API        = $Api
            Port       = $Port
            URI        = $Uri
            Fees       = @($Fees)
        }
    }
}
