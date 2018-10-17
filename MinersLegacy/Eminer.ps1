﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)
$Path = ".\Bin\AMD_NVIDIA-Eminer-Ethash\eminer.exe"
$HashSHA256 = "B4D0723F5BE34731108B558B8BA9E9F1DFCE92AFD6C2D93D9A7FD0E0C55430D3"
$Uri = "https://github.com/ethash/eminer-release/releases/download/v0.6.1-rc2/eminer.v0.6.1-rc2.win64.zip"
$ManualUri = "https://github.com/ethash/eminer-release"
$Port = "74{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "ethash2gb"; MinMemGB = 2; Params = @()} #Ethash2GB
    [PSCustomObject]@{Algorithm = "ethash3gb"; MinMemGB = 3; Params = @()} #Ethash3GB
    [PSCustomObject]@{Algorithm = "ethash"   ; MinMemGB = 4; Params = @()} #Ethash
)
$CommonCommands = " -no-devfee -intensity 64"

# Set devfee default coin, it may reduce DAG changes
$DevFeeCoin  = [PSCustomObject]@{
    "Ethereum" = " -devfee-coin ETH"
    "Eth" = " -devfee-coin ETH"
    "EthereumClassic" = "-devfee-coin ETC"
    "Etc" = "-devfee-coin ETC"
    "Expanse" = " -devfee-coin EXP"
    "Exp" = " -devfee-coin EXP"
    "Music" = " -devfee-coin MUSIC"
    "MusiCoin" = " -devfee-coin MUSIC"
    "Ubiq" = " -devfee-coin UBQ"
    "Ubq" = " -devfee-coin UBQ"
}

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = @($Devices | Where-Object Type -EQ "GPU")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $MinMem = $_.MinMemGB * 1GB

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMem})) {

            $Miner_Name = ((@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"

            [PSCustomObject]@{
                Name                 = $Miner_Name
                DeviceName           = $Miner_Device.Name
                Path                 = $Path
                HashSHA256           = $HashSHA256
                Arguments            = ("-http :$Miner_Port -S $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -U $($Pools.$Algorithm_Norm.User) -P $($Pools.$Algorithm_Norm.Pass)$(if($Config.WorkerName) {" -N $($Config.WorkerName)"})$(if($DevfeeCoin.($Pools.$Algorithm_Norm.CoinName)) {"$($DevfeeCoin.($Pools.$Algorithm_Norm.CoinName))"})$($Commands.$_)$CommonCommands -M $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Index)}) -join ',')" -replace "\s+", " ").trim()
                HashRates            = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API                  = "Eminer"
                Port                 = $Miner_Port
                URI                  = $Uri
            }
        }
    }
}
