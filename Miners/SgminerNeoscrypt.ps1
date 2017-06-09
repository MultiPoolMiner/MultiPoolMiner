. .\Include.ps1

$Path = ".\Bin\NeoScrypt-AMD\nsgminer.exe"
$Uri = "https://github.com/ghostlander/nsgminer/releases/download/nsgminer-v0.9.2/nsgminer-win64-0.9.2.zip"

$Commands = [PSCustomObject]@{
    "neoscrypt" = " --gpu-threads 1 --worksize 64 --intensity 13 --thread-concurrency 64" #NeoScrypt
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-listen --$_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$Name_$(Get-Algorithm($_))_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        Wrap = $false
        URI = $Uri
    }
}