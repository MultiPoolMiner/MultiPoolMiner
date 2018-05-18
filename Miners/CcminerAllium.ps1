using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Allium\ccminer-x64.exe"
$HashSHA256 = "70117C8CBADB642E5E1C587FA0CA3AE1B910FCC0A030CA8884750332DB89D95B"
$Uri = "http://ccminer.org/preview/ccminer-x64-2.2.6-xmr-allium-cuda9.7z"

$Commands = [PSCustomObject]@{
    "allium" = "" #Allium
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
    }
}
