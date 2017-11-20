using module ..\Include.psm1

$Path = ".\Bin\Xevan-AMD\sgminer.exe"
$Uri = "https://github.com/LIMXTEC/Xevan-GPU-Miner/releases/download/1/sgminer-xevan-5.5.0-nicehash-1-windows-amd64.zip"

$Commands = [PSCustomObject]@{
    "xevan-mod" = " --intensity 15" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        Wrap = $false
        URI = $Uri
    }
}