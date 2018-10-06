using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-CuBalloon\cuballoon.exe"
$HashSHA256 = "F6D5315AC40A099D3593E5BC60AB5D24A994E024292CFD924D2A0F7141E76256"
$Uri = "https://github.com/Belgarion/cuballoon/files/2143221/CuBalloon.1.0.2.Windows.zip"

$Commands = [PSCustomObject]@{
    "balloon" = ""
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    
    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type             = "NVIDIA"
        Path             = $Path
        HashSHA256       = $HashSHA256
        Arguments        = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --cuda_threads 128,128,128,128,128,128,128,128,128,128,128,128 --cuda_blocks 48,48,48,48,48,48,48,48,48,48,48,48 --cuda_sync 0 -t 0"
        HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API              = "Ccminer"
        Port             = 4048
        URI              = $Uri
    }
}
