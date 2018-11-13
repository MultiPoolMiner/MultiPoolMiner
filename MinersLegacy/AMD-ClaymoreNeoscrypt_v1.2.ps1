using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\NeoScryptMiner.exe"
$HashSHA256 = "AF7E52C6F71B2B114299BB2AFAAF11B65800AC0390C037473E0CEBAE8E9D4BC5"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/neoscryptminer/Claymore.s.NeoScrypt.AMD.GPU.Miner.v1.2.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=3012600.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "neoscrypt" = "" #NeoScrypt
}
$CommonCommands = " -a 2 -dbg -1" #turn off all logs

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

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
            Arguments  = ("-r -1 -mport -$Miner_Port -pool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -psw $($Pools.$Algorithm_Norm.Pass) -di $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join '')$($Commands.$_)$CommonCommands" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Claymore"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = $MinerFee
        }
    }
}
