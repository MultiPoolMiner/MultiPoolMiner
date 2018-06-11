using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NeoScrypt-Claymore\NeoScryptMiner.exe"
$HashSHA256 = "AF7E52C6F71B2B114299BB2AFAAF11B65800AC0390C037473E0CEBAE8E9D4BC5"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/neoscryptminer/Claymore.s.NeoScrypt.AMD.GPU.Miner.v1.2.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=3012600.0"
$Port = 13333
$MinerFeeInPercent = 2.5
$MinerFeeInPercentSSL = 2
$Commands = [PSCustomObject]@{
    "neoscrypt" = "" #NeoScrypt
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
        Arguments  = "-r -1 -mport -$Port -pool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -psw $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API        = "Claymore"
        Port       = $Port
        URI        = $Uri
        Fees       = $Fees
    }
} 
