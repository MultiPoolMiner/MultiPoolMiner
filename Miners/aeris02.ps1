using module ..\Include.psm1

$Path = ".\Bin\AMD-Aeris\sgminer.exe"
$HashSHA256 = "6da505b3459cfa86f9f241c6ea3219f9c386c149c8a84192a76d9b8797b8afd0"
$Uri = "https://mega.nz/#F!v6JSXBqK!2jQLwNjgaIV3IoN8OHgfzw"

$Commands = [PSCustomObject]@{
    "X17" = " --worksize 32 --intensity 18" #X17
    "X16s" = " --worksize 32 --intensity 18" #X16s
    "X16r" = " --worksize 32 --intensity 18" #X16r
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        HashSHA256 = $HashSHA256
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}
