. .\Include.ps1

$Path = ".\Bin\Skein-AMD\sgminer.exe"
$Uri = "https://github.com/miningpoolhub/sgminer/releases/download/5.3.1/Release.zip"

$Commands = [PSCustomObject]@{
    "skeincoin" = " --gpu-threads 2 --worksize 256 --intensity 23" #Skein
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm($_)).Protocol)://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$Name_$(Get-Algorithm($_))_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        Wrap = $false
        URI = $Uri
    }
}