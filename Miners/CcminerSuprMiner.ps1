using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-SuprMiner\ccminer.exe"
$Uri = "https://github.com/ocminer/suprminer/releases/download/1.3/suprminer-1.3b.7z"

$Commands = [PSCustomObject]@{
    "x16r"  = "" #X16R RavenCoin
    "x16s"  = "" #X16S PigeonCoin
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}
