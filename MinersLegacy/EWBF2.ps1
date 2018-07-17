﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-EWBF2-Equihash\miner.exe"
$HashSHA256 = "EF09B92F84CC1B2A4DEADF4C3937D9ADF651DAB51DA6DD77359CB0B187AC8DA6"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/EWBF2/EWBF.Equihash.miner.v0.3.zip"
$ManualUri = "https://mega.nz/#F!fsAlmZQS!CwVgFfBDduQI-CbwVkUEpQ"
$Port = "421{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash-96_5";  MinMemGB = 2; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-144_5"; MinMemGB = 2; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-192_7"; MinMemGB = 3; Params = ""}
)

$CommonCommands = " --fee 0 --intensity 64"

$Coins = [PSCustomObject]@{
    "BitcoinGold" = " --pers BgoldPoW"
    "BitcoinZ"    = " --pers BitcoinZ"
    "Minexcoin"   = ""
    "SnowGem"     = " --pers sngemPoW"
    "Zero"        = " --pers ZERO_PoW"
    "ZeroCoin"    = " --pers ZERO_PoW"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                
    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm = ($_.Algorithm) -replace "Equihash-"
        $Algorithm_Norm = Get-Algorithm $_.Algorithm
        $MinMemGB = $_.MinMemGB
        
        if ($Miner_Device = @($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1000000000)})) {
            [PSCustomObject]@{
                Name             = $Miner_Name
                DeviceName       = $Miner_Device.Name
                Path             = $Path
                HashSHA256       = $HashSHA256
                Arguments        = ("--algo $($Algorithm)$($Coins."$($Pools.$Algorithm_Norm.CoinName)") --eexit 1 --api 127.0.0.1:$($Miner_Port) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($_.Params)$CommonCommands --cuda_devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join '')" -replace "\s+", " ").trim()
                HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API              = "DSTM"
                Port             = $Miner_Port
                URI              = $Uri
                Fees             = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
                ExtendInterval   = 2
                PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
            }
        }
    }
}