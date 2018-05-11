 using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Zealot\z-enemy.exe"
$HashSHA256 = "15F401E8AF15884440C5A8940C9E91934A3A7AF484DA3ACAB9237087D010F42A"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/zenemy109/z-enemy.109a-release.zip"

$Commands = [PSCustomObject]@{
    "bitcore" = "" #Bitcore
    "phi"     = "" #PHI
    "x16r"    = "" #Raven
    "x16s"    = "" #Pigeon
    "xevan"   = "" #Xevan, new in 1.09a
    "vit"     = "" #Vitality, new in 1.09a
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        HashSHA256 = $HashSHA256
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
} 
