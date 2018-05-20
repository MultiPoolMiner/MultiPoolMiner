using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-ZEnemy\z-enemy.exe"
$HashSHA256 = ""
$Uri = ""
$MinerFeeInPercent = 1

$Commands = [PSCustomObject]@{
    "bitcore" = "" #Bitcore
    "phi"     = "" #PHI
    "vit"     = "" #Vitality
    "x16r"    = "" #Raven
    "x16s"    = "" #Pigeon
    "x17"     = "" #X17
    "xevan"   = "" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
                
if ($Config.IgnoreMinerFee -or $Config.Miners.$Name.IgnoreMinerFee) {
    $Fees = @($null)
}
else {
    $Fees = @($MinerFeeInPercent)
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week
    if ($Fees) {$HashRate = $HashRate * (1 - $MinerFeeInPercent / 100)}

    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
        Fees       = $Fees
    }
} 
