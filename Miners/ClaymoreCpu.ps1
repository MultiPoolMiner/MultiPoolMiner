using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-Claymore-Cpu\NsCpuCNMiner64.exe"
$HashSHA256 = "D7D80BF3F32C20298CAD1D59CA8CB4508BAD43A9BE5E027579D7FC77A8E47BE0"
$API = "Claymore"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/claymorecpu/Claymore.CryptoNote.CPU.Miner.v4.0.-.POOL.zip"
$Port = 3333

$Commands = [PSCustomObject]@{
    "CryptoNight"          = @("0","") #CryptoNight, first item is algo number, second for additional miner commands
    "CryptoNightV7"        = @("1","") #CryptoNightV7
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_
    
    if ($Pools.$Algorithm_Norm) { # must have a valid pool to mine

        $HashRate = ($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)

        [PSCustomObject]@{
            Name       = $Name
            Type       = "CPU"
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-r -1 -mport -$Port -pow7 $($Commands.$_ | Select-Object -Index 0) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_ | Select-Object -Index 1)\")
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
            API        = $Api
            Port       = $Port
            URI        = $Uri
            Fees       = @($null)
        }
    }
}
