using module ..\Include.psm1

$Path = ".\Bin\AMD-Gatelessgate\gatelessgate.exe"
$HashSHA256 = "a579d72d8c0318a7cce01e9d1573ef9dc6af77d0fdf4249aaf054aee381095e8"
$Uri = "https://github.com/zawawawa/gatelessgate/releases/download/v0.1.3-pre6b/gatelessgate-0.1.3-pre6b-win64.zip"

$Commands = [PSCustomObject]@{
    "equihash" = " --gpu-threads 2 --intensity 16" #Equihash
    "neoscrypt" = " --intensity 14" #NeoScrypt
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
	HashSHA256 = $HashSHA256
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}
