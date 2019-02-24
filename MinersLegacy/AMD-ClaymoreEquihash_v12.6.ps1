using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ZecMiner64.exe"
$HashSHA256 = "46294BF3FD21DD0EE3CC0F0D376D5C8DFB341DE771B47F00AE2F02E7660F06B9"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/zecminer64/Claymore.s.ZCash.AMD.GPU.Miner.v12.6.-.Catalyst.15.12-17.x.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=1670733.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "equihash" = "" #Equihash
}
$CommonCommands = " -dbg -1" #turn off all logs

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = <#temp fix#> Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        if ($Pools.$Algorithm_Norm.SSL) {
            $MinerFee = [PSCustomObject]@{"$Algorithm_Norm" = 2.5 / 100}
        }
        else {
            $MinerFee = [PSCustomObject]@{"$Algorithm_Norm" = 2 / 100}
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-r -1 -mport -$Miner_Port -zpool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -zwal $($Pools.$Algorithm_Norm.User) -zpsw $($Pools.$Algorithm_Norm.Pass) -allpools 1 -di $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_PlatformId_Index)}) -join '')$($Commands.$_)$CommonCommands" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Claymore"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = $MinerFee
        }
    }
}
