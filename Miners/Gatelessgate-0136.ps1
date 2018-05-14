using module ..\Include.psm1

$Path = ".\Bin\Gatelessgate-0136\gatelessgate.exe"
$Uri = "https://github.com/zawawawa/gatelessgate/releases/download/v0.1.3-pre6b/gatelessgate-0.1.3-pre6b-win64.zip"

$Commands = [PSCustomObject]@{
    "equihash" = " --gpu-threads 2 --intensity 16" #Equihash
	"zec" = " --gpu-threads 2 --intensity 16" #Equihash
    "neoscrypt" = " --intensity 14" #NeoScrypt
	"phoenixcoin" = " --intensity 14" #NeoScrypt
	"trezarcoin" = " --intensity 14" #NeoScrypt
	"feathercoin" = " --intensity 14" #NeoScrypt
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
        URI = $Uri
    }
}
