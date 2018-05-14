using module ..\Include.psm1

$Path = ".\Bin\AMD-Lyra2z-djm3403\sgminer.exe"
$HashSHA256 = "a63f63c723cd896ac4434ccc03d4074a7794ae39e6b1e80003825d62dfe9b44e"
$Uri = "https://github.com/djm34/sgminer-msvc2015/releases/download/v0.3/kernel.rar"

$Commands = [PSCustomObject]@{
    "lyra2z" = " --worksize 32 --intensity 18" #Lyra2z
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
