using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-ZFastLyra2Z\zFastminer-v229.exe"
$Uri = "https://github.com/iwtym/iwtym-zfastminer/archive/master.zip"

$Commands = [PSCustomObject]@{
    "lyra2z" = "" #Lyra2z
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a lyra2z -o stratum+tcp://us-east.lyra2z-hub.miningpoolhub.com:20581 -u nujan.NewWORKERNAME -p x"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}