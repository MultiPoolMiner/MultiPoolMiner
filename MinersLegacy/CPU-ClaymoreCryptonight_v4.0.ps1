using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\NsCpuCNMiner64.exe"
$HashSHA256 = "D7D80BF3F32C20298CAD1D59CA8CB4508BAD43A9BE5E027579D7FC77A8E47BE0"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/claymorecpu/Claymore.CryptoNote.CPU.Miner.v4.0.-.POOL.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=647251.0"
$Port = 3333

$Commands = [PSCustomObject]@{
    "cryptonightV7" = "" #CryptoNightV7
    #"cryptonight"  = "" #CryptoNight, ASIC 
}
$CommonCommands = " -dbg -1" #no log file and no debug messages

$Devices = $Devices | Where-Object Type -EQ "CPU"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_;"$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-r -1 -mport -$($Miner_Port) -pow7 1 -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)($Commands.$_)$CommonCommands" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Claymore"
            Port       = $Miner_Port
            URI        = $Uri
        }
    } 
}
