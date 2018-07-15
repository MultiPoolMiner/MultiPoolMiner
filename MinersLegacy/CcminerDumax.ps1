using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Dumax\ccminer.exe"
$HashSHA256 = "715EE772A023218044B14C5C9D7D41AA936F5FA5791EF10E4924A5DDAAF9B781"
$Uri = "https://github.com/DumaxFr/ccminer/releases/download/dumax-0.9.3/ccminer-dumax-0.9.3-win64.zip"

$Commands = [PSCustomObject]@{
    "phi"           = "" 
    "phi2"          = "" #LUX
    "x16r"          = "" #X16r
    "x16s"         = "" #X16s
    "x17"          = "" #x17
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    Switch ($Algorithm_Norm) {
        "PHI"   {$ExtendInterval = 3}
        "PHI2"   {$ExtendInterval = 3}
        "X16R"  {$ExtendInterval = 10}
        "X16S"  {$ExtendInterval = 10}
        default {$ExtendInterval = 0}
    }

    [PSCustomObject]@{
        Type           = "NVIDIA"
        Path           = $Path
        HashSHA256     = $HashSHA256
        Arguments      = "-R 1 -q -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --submit-stale"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API            = "Ccminer"
        Port           = 4068
        URI            = $Uri
        ExtendInterval = $ExtendInterval
    }
}
