using module ..\Include.psm1

$Path = ".\Bin\AMD-Bitcore\sgminer-x64.exe"
$HashSHA256 = "C00DE0D33BD20BE3B5014FC019ED8A81D3AA5273C8AF96B17D6B51C5D8FA3933"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/sgminerbitcore/sgminer-bitcore-5.6.1.9.zip"

$Commands = [PSCustomObject]@{
    "timetravel10" = " --intensity 19" #Bitcore
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "AMD"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Xgminer"
        Port       = 4028
        URI        = $Uri
    }
}
