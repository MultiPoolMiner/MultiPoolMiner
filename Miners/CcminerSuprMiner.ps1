using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-SuprMiner\ccminer.exe"
$HashSHA256 = "6DE5DC4F109951AE1591D083F5C2A6494C9B59470C15EF6FBE5D38C50625304B"
$Uri = "https://github.com/ocminer/suprminer/releases/download/1.5/suprminer-1.5.7z"

$Commands = [PSCustomObject]@{
    #"x16r"  = "" #X16R RavenCoin
    "x16s"  = "" #X16S PigeonCoin
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
