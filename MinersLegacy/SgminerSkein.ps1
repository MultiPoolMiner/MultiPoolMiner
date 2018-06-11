using module ..\Include.psm1

$Path = ".\Bin\Skein-AMD\sgminer.exe"
$HashSHA256 = "C97D959551EBEA1A7092A66CA643B4A7EE21007F095D4F9649A6F1CA550258D4"
$Uri = "https://github.com/miningpoolhub/sgminer/releases/download/5.3.1/Release.zip"

$Commands = [PSCustomObject]@{
    "skeincoin" = " --gpu-threads 2 --worksize 256 --intensity d" #Skein
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        HashSHA256       = $HashSHA256
        Arguments        = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API              = "Xgminer"
        Port             = 4028
        URI              = $Uri
        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
        PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
    }
}