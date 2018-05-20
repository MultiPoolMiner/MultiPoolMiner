using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Type = "AMD"
if (-not ($Devices.$Type -or $Config.InfoOnly)) {return} # No AMD mining device present in system, InfoOnly is for Get-Binaries

$Path = ".\Bin\CryptoNight-AMD\xmrig-amd.exe"
$HashSHA256 = "8D1867696FFD1D5EB628E88CC1293D39484F5536CB84E8441053E13F992E8515"
$API = "XMRig"
$Uri = "https://github.com/xmrig/xmrig-amd/releases/download/v2.6.1/xmrig-amd-2.6.1-win64.zip"
$Port = 3335
$MinerFeeInPercent = 1

$Commands = [PSCustomObject]@{
    "cn"       = "" #CryptoNightV7
    "cn-heavy" = "" #CryptoNight-Heavy
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
    $Fees = @($null)
}
else {
    $Fees = @($MinerFeeInPercent)
}

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
            Arguments  = ("--api-port $Port -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --keepalive --nicehash --donate-level 1")
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
            API        = $Api
            Port       = $Port
            URI        = $Uri
            Fees       = @($Fees)
        }
    }
}
