using module ..\Include.psm1

$Path = ".\Bin\Lyra2RE2-NVIDIA\ccminer.exe"
$Uri = "https://github.com/nicehash/ccminer-nanashi/releases/download/1.7.6-r6/ccminer.zip"

$Commands = [PSCustomObject]@{
    "lyra2v2" = "" #Lyra2RE2
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}