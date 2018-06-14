using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Zealot\z-enemy.exe"
$HashSHA256 = "EC96FD647DAE59F49A727B78E3BB132608339C1E25E9DC6FCAD6C00B6726C13C"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Zenemy/z-enemy.1-11-public-final_v3.1.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"

$Commands = [PSCustomObject]@{
    "aeriumx"    = "" #AeriumX, new in 1.11
    "bitcore"    = "" #Bitcore
    "c11"        = "" # New in 1.11
    "phi"        = "" #PHI
    "polytimos"  = "" #Polytimos
    "skunk"      = "" #Skunk, new in 1.11
    "timetravel" = "" #Timetravel8
    "tribus"     = "" #Tribus, new in 1.10
    "x16r"       = " -N 100" #Raven, number of samples used to compute hashrate (default: 30) 
    "x16s"       = "" #Pigeon
    "x17"        = "" #X17
    "xevan"      = "" #Xevan, new in 1.09a
    "vit"        = "" #Vitality, new in 1.09a
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
        Fees       = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
    }
} 
