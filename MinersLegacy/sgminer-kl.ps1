using module ..\Include.psm1

$Path = ".\Bin\sgminer-kl\sgminer.exe"
$HashSHA256 = "A24024BEA8789B62D61CB3F41432EA1A62EE5AD97CD3DEAB1E2308F40B127A4D"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.5fix/sgminer-kl-1.0.5_fix-windows_x64.zip"

$Commands = [PSCustomObject]@{
    "Aergo" = " -X 256 -g 2" #aergo
	"Phi" = "  -X 256 -g 2 -w 256" #phi
	"Tribus" = "  -X 256 -g 2" #tribus
	"x16r" = "  -X 256 -g 2" #x16r
	"x16s" = "  -X 256 -g 2" #x16s
	"X17" = "  -X 256 -g 2" #x17
	"Xevan" = "  -X 256 -g 2" #xevan

}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "AMD"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Xgminer"
        Port       = 4028
        URI        = $Uri
    }
}
