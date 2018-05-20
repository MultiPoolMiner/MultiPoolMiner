using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Type = "NVIDIA"
if (-not ($Devices.$Type -or $Config.InfoOnly)) {return} # No NVIDIA mining device present in system, InfoOnly is for Get-Binaries

$Path = ".\Bin\CryptoNight-NVIDIA\xmrig-nvidia.exe"
$HashSHA256 = "5905924C61D96267C176BC9AF86C16DCC837B81378E47315231A9EE0C5CC48B7"
$API = "XMRig"
$Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.6.1/xmrig-nvidia-2.6.1-cuda9-win64.zip"
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
            Arguments  = ("--api-port $Port -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --keepalive --nicehash --donate-level 1 --cuda-bfactor=11")
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
            API        = $Api
            Port       = $Port
            URI        = $Uri
            Fees       = @($Fees)
        }
    }
}
