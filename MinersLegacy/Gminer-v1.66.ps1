﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\miner.exe"
$HashSHA256 = "051DC4B525C4DEBDBF9261D97C9000C25879CC73B75B243E45E91B6CB74FD379"
$Uri = "https://github.com/develsoftware/GMinerRelease/releases/download/1.66/gminer_1_66_windows64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5034735.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "EquihashR15053"; MinMemGB = 4.0; Vendor = @("AMD", "NVIDIA"); Command = " --algo BeamHashII --OC1"} #new in v1.55
    [PSCustomObject]@{Algorithm = "Cuckaroo29";     MinMemGB = 4.0; Vendor = @("AMD", "NVIDIA"); Command = " --algo cuckaroo29"} #new in v1.19; Cuckaroo29 / Grin
    [PSCustomObject]@{Algorithm = "Cuckaroo29s";    MinMemGB = 4.0; Vendor = @("AMD", "NVIDIA"); Command = " --algo cuckaroo29s"} #new in v1.34; Cuckaroo29s / Swap
    [PSCustomObject]@{Algorithm = "Cuckatoo31";     MinMemGB = 7.4; Vendor = @("NVIDIA");        Command = " --algo cuckatoo31"} #new in v1.31; Cuckatoo31 / Grin
    [PSCustomObject]@{Algorithm = "Cuckarood29";    MinMemGB = 1.0; Vendor = @("NVIDIA");        Command = " --algo grin29"} #new in v1.51
    [PSCustomObject]@{Algorithm = "Cuckoo29";       MinMemGB = 4.0; Vendor = @("AMD", "NVIDIA"); Command = " --algo cuckoo29"} #new in v1.24; Cuckoo29 / Aeternity
    [PSCustomObject]@{Algorithm = "Equihash965";    MinMemGB = 0.8; Vendor = @("NVIDIA");        Command = " --algo equihash96_5"} #new in v1.13
    [PSCustomObject]@{Algorithm = "Equihash1254";   MinMemGB = 1.0; Vendor = @("AMD", "NVIDIA"); Command = " --algo equihash125_4"} #new in v1.46; ZelCash
    [PSCustomObject]@{Algorithm = "Equihash1445";   MinMemGB = 1.8; Vendor = @("AMD", "NVIDIA"); Command = " --algo equihash144_5"}
    [PSCustomObject]@{Algorithm = "Equihash1927";   MinMemGB = 2.8; Vendor = @("NVIDIA");        Command = " --algo equihash192_7"}
    [PSCustomObject]@{Algorithm = "Equihash2109";   MinMemGB = 1.0; Vendor = @("NVIDIA");        Command = " --algo equihash210_9"} #new in v1.09
    [PSCustomObject]@{Algorithm = "Grimm";          MinMemGB = 1.0; Vendor = @("AMD", "NVIDIA"); Command = " --algo grimm"} #new in v1.54; Grimm
    [PSCustomObject]@{Algorithm = "vds";            MinMemGB = 1.0; Vendor = @("AMD", "NVIDIA"); Command = " --algo vds"} #new in v1.43; Vds / V-Dimension
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices = $Devices | Where-Object Type -EQ "GPU"
$Devices | Select-Object Type, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Type -EQ $_.Type | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$_.Vendor -contains ($Device.Vendor_ShortName | Select-Object -Unique) -and $Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $MinMemGB = $_.MinMemGB
        
        #Windows 10 requires 1 GB extra
        if ($_.Algorithm -match "cuckaroo29|cuckarood29|cuckaroo29s|cuckoo" -and ([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) {$MinMemGB += 1}

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

            Switch ($Algorithm_Norm) {
                "Equihash1445"   {$Pers = " --pers $(Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default "auto")"}
                "Equihash1927"   {$Pers = " --pers $(Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default "auto")"}
                Default          {$Pers = ""}
            }

            [PSCustomObject]@{
                Name               = $Miner_Name
                BaseName           = $Miner_BaseName
                Version            = $Miner_Version
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("$Command$CommonCommands$Pers --api $($Miner_Port)$(if ($Pools.$Algorithm_Norm.SSL) {" --ssl --ssl_verification 0"}) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) --devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.PCIBus_Type_Index)}) -join ' ')" -replace "\s+", " ").trim()
                HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API                = "Gminer"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
                WarmupTime         = 45 #seconds
            }
        }
    }
}
