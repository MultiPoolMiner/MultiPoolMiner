using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-Claymore\NsGpuCNMiner.exe"
$HashSHA256 = "2EF61DC0157469315831CD6486711617DB80B819AB9E10DB9FDD9D66D95D3F28"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/claymorecryptonoteamd/Claymore.CryptoNote.AMD.GPU.Miner.v11.3.-.POOL.-.Catalyst.15.12-18.x.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=638915.0"
$Port = 13333
$Commands = [PSCustomObject]@{
    "cryptonightV7"   = " -pow7 1" #CryptoNightV7
    "cryptonightLite" = " -lite 1" #CryptoNightLite
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
                
$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_
    $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week

    [PSCustomObject]@{
        Type       = "AMD"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-r -1 -mport -$Port -xpool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -xwal $($Pools.$Algorithm_Norm.User) -xpsw $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API        = "Claymore"
        Port       = $Port
        URI        = $Uri
        Fees       = $Fees
    }
} 
