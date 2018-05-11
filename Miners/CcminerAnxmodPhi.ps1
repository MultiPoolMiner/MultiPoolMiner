using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-PHI\ccminer.exe"
$HashSHA256 = "6C3AFFABBD39566F4AE3B78CF55BFEA06BE98C1D48FDDB27DEE406DB87B7663F"
$URI = "https://github.com/216k155/ccminer-phi-anxmod/releases/download/ccminer%2Fphi-1.0/ccminer-phi-1.0.zip"

$Commands = [PSCustomObject]@{
    "Phi" = "" #Phi Phi1612 LUX
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
