using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Zealot\z-enemy.exe"
$HashSHA256 = "50F366AC61B30FA2A8229552586DF4F538D2FE8A1FF0C9AA5CD75DEF2351B585"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Zenemy/z-enemy.1-12-cuda9.1-public.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"

$Commands = [PSCustomObject]@{
    "aeriumx"    = "" #AeriumX, new in 1.11
    "bitcore"    = "" #Bitcore
    "c11"        = "" #C11, new in 1.11
    "phi"        = "" #Phi
    "phi2"       = "" #Phi2
    "polytimos"  = "" #Polytimos
    "skunk"      = "" #Skunk, new in 1.11
    "sonoa"      = "" #SONOA, new in 1.12
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

    Switch ($Algorithm_Norm) {
        "PHI"   {$ExtendInterval = 3}
        "PHI2"  {$ExtendInterval = 3}
        "X16R"  {$ExtendInterval = 10}
        "X16S"  {$ExtendInterval = 10}
        default {$ExtendInterval = 0}
    }

    [PSCustomObject]@{
        Type           = "NVIDIA"
        Path           = $Path
        HashSHA256     = $HashSHA256
        Arguments      = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API            = "Ccminer"
        Port           = 4068
        URI            = $Uri
        Fees           = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
        ExtendInterval = $ExtendInterval
    }
} 
