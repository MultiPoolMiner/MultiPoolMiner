using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-Claymore-Cpu\NsCpuCNMiner64.exe"
$HashSHA256 = "D7D80BF3F32C20298CAD1D59CA8CB4508BAD43A9BE5E027579D7FC77A8E47BE0"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/claymorecpu/Claymore.CryptoNote.CPU.Miner.v4.0.-.POOL.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=647251.0"
$Port = 3333
$Commands = [PSCustomObject]@{
    "cryptonightV7" = "" #CryptoNightV7
    #"cryptonight"  = "" #CryptoNight, ASIC 
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
                
$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_
    $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week

    [PSCustomObject]@{
        Type       = "CPU"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-r -1 -mport -$Port -pow7 1 -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API        = "Claymore"
        Port       = $Port
        URI        = $Uri
        Fees       = $Fees
    }
} 
