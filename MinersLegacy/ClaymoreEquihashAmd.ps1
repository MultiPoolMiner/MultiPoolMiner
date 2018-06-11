using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Equihash-Claymore\ZecMiner64.exe"
$HashSHA256 = "46294BF3FD21DD0EE3CC0F0D376D5C8DFB341DE771B47F00AE2F02E7660F06B9"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/zecminer64/Claymore.s.ZCash.AMD.GPU.Miner.v12.6.-.Catalyst.15.12-17.x.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=1670733.0"
$MinerFeeInPercent = 2.5
$MinerFeeInPercentSSL = 2
$Port = 13333
$Commands = [PSCustomObject]@{
    "equihash" = "" #Equihash
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
                
$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_
    $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week

    if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
        $Fees = @($null)
    }
    else {
        if ($Pools.$Algorithm_Norm.SSL) {
            $MinerFeeInPercent = $MinerFeeInPercentSSL
        }
        $Fees = @($MinerFeeInPercent)
        $HashRate = $HashRate * (1 - $MinerFeeInPercent / 100)
    }

    [PSCustomObject]@{
        Type       = "AMD"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-r -1 -mport -$Port -zpool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -zwal $($Pools.$Algorithm_Norm.User) -zpsw $($Pools.$Algorithm_Norm.Pass) -allpools 1$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API        = "Claymore"
        Port       = $Port
        URI        = $Uri
        Fees       = $Fees
    }
} 
