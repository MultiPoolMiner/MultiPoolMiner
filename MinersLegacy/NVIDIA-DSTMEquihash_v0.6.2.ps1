﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\zm.exe"
$HashSHA256 = "1C8F4B7C252FD2C2F58F69F9D39FD89D255B9DAB1CDA4AC0BC8137EE60C383C6"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/dstm/zm_0.6.2_win.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=2021765.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        #GPU - profitable 20/04/2018
        "equihash" = "" #Equihash
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --color"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

        #Get parameters for active miner devices
        if ($Miner_Config.Parameters.$Algorithm_Norm) {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
        }
        elseif ($Miner_Config.Parameters."*") {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
        }
        else {
            $Parameters = Get-ParameterPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("--telemetry=127.0.0.1:$($Miner_Port) --server $(if ($Pools.$Algorithm_Norm.SSL) {'ssl://'})$($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters --dev $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "DSTM"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
        } 
    }
}
