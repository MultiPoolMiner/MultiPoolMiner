using module ..\Include.psm1

$Path = ".\Bin\AMD-KL\sgminer.exe"
$HashSHA256 = "9029ba519b2805c24e2168050a9878f16bf5988e5fb90c80200bd451983c9fc9"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.1/sgminer-kl-1.0.1-windows.zip"

$Commands = [PSCustomObject]@{
    "x16r" = " -X 256 -g 2 --intensity 18" #Raven increase 19,21
    "x16s" = " -X 256 -g 2" #x16s
    "x17" = " -X 256 -g 2" #x17
    "xevan" = " -X 256 -g 2" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
	HashSHA256 = $HashSHA256
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week * 0.99}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}
