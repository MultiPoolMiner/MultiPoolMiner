using module ..\Include.psm1

$Path = ".\Bin\NeoScrypt-JAM\hsrminer_neoscrypt_fork_hp.exe"
$HashSHA256 = "571B1C7D7A0BB9934AAF3E4106C26B7735A004473E9ECD99D35C4E2664487EFF"
$Uri = "https://github.com/justaminer/hsrm-fork/raw/master/hsrminer_neoscrypt_fork_hp.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=2765610.0"

$Commands = [PSCustomObject]@{
    "neoscrypt" = "" #NeoScrypt
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
        Fees       = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
    }
}
