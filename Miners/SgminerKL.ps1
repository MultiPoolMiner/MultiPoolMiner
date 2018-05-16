using module ..\Include.psm1

$Path = ".\Bin\AMD-KL\sgminer.exe"
$HashSHA256 = "9029BA519B2805C24E2168050A9878F16BF5988E5FB90C80200BD451983C9FC9"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.1/sgminer-kl-1.0.1-windows.zip"

$Commands = [PSCustomObject]@{
    "x16r" = " -X 256 -g 2 --intensity 18" #Raven increase 19,21
    "x16s" = " -X 256 -g 2" #x16s
    "x17" = " -X 256 -g 2" #x17
    "xevan" = " -X 256 -g 2" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        HashSHA256 = $HashSHA256
        Arguments = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}