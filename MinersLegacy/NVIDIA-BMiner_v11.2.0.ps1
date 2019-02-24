﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\BMiner.exe"
$HashSHA256 = "EAFFD560100E71538886DC591760CFC19A1B5D2906262D3C2D295DAD04590FAF"
$Uri = "https://www.bminercontent.com/releases/bminer-lite-v11.2.0-a1b8f66-CUDA-9.2-amd64.zip"

# Miner requires CUDA 9.2.00 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$ManualUri = "https://bitcointalk.org/index.php?topic=2519271.1320"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    #Single algo mining
    [PSCustomObject]@{MainAlgorithm = "aeternity";    MinMemGB = 2; Params = ""} #Aeternity, new in 11.1.0
    [PSCustomObject]@{MainAlgorithm = "equihash";     MinMemGB = 2; Params = ""} #Equihash
    [PSCustomObject]@{MainAlgorithm = "equihash1445"; MinMemGB = 2; Params = ""} #Equihash1445
    [PSCustomObject]@{MainAlgorithm = "ethash2gb";    MinMemGB = 2; Params = ""} #Ethash2Gb
    [PSCustomObject]@{MainAlgorithm = "ethash3gb";    MinMemGB = 3; Params = ""} #Ethash3Gb
    [PSCustomObject]@{MainAlgorithm = "ethash";       MinMemGB = 4; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "tensority";    MinMemGB = 2; Params = ""} #Bytom
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "blake14r";  MinMemGB = 2; Params = ""} #Ethash2Gb & Blake14r dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; SecondaryAlgorithm = "blake14r";  MinMemGB = 3; Params = ""} #Ethash3Gb & Blake14r dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash";    SecondaryAlgorithm = "blake14r";  MinMemGB = 4; Params = ""} #Ethash & Blake14r dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "blake2s";   MinMemGB = 2; Params = ""} #Ethash2Gb & Blake14r dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; SecondaryAlgorithm = "blake2s";   MinMemGB = 3; Params = ""} #Ethash3Gb & Blake14r dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash";    SecondaryAlgorithm = "blake2s";   MinMemGB = 4; Params = ""} #Ethash & Blake14r dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "tensority"; MinMemGB = 2; Params = ""} #Ethash2Gb & Bytom dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; SecondaryAlgorithm = "tensority"; MinMemGB = 3; Params = ""} #Ethash3Gb & Bytom dual mining, auto dual solver and intensity
    [PSCustomObject]@{MainAlgorithm = "ethash";    SecondaryAlgorithm = "tensority"; MinMemGB = 4; Params = ""} #Ethash & Bytom dual mining, auto dual solver and intensity

    #Custom config, manually set dual solver (Values: -1, 0, 1, 2, 3) and secondary intensity (Values: 0 - 300)
#    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "blake14r"; DualSubsolver = 0; SecondaryIntensity = 00;  MinMemGB = 2; Params = ""} #Ethash2Gb & Blake14r dual mining
#    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "blake2s";  DualSubsolver = 0; SecondaryIntensity = 50;  MinMemGB = 2; Params = ""} #Ethash2Gb & Blake2S dual mining
#    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; SecondaryAlgorithm = "blake14r"; DualSubsolver = 0; SecondaryIntensity = 00;  MinMemGB = 3; Params = ""} #Ethash3Gb & Blake14r dual mining
#    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; SecondaryAlgorithm = "blake2s";  DualSubsolver = 0; SecondaryIntensity = 50;  MinMemGB = 3; Params = ""} #Ethash3Gb & Blake2S dual mining
#    [PSCustomObject]@{MainAlgorithm = "ethash";    SecondaryAlgorithm = "blake14r"; DualSubsolver = 0; SecondaryIntensity = 00;  MinMemGB = 4; Params = ""} #Ethash & Blake14r dual mining
#    [PSCustomObject]@{MainAlgorithm = "ethash";    SecondaryAlgorithm = "blake2s";  DualSubsolver = 0; SecondaryIntensity = 50;  MinMemGB = 4; Params = ""} #Ethash & Blake2S dual mining
)
$CommonCommands = " -watchdog=false"

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | ForEach-Object {
        $Arguments_Secondary = ""
        $Main_Algorithm = $_.MainAlgorithm
        $Main_Algorithm_Norm = Get-Algorithm $Main_Algorithm
        $Params = $_.Params
        $MinMemGB = $_.MinMemGB

        if ($Pools.$Main_Algorithm_Norm.Host -and ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB}))) {
            if ($Main_Algorithm_Norm -like "Equihash1445") {
            #define -pers for equihash1445
                $Pers = " -pers $(Get-EquihashPers -CoinName $Pools.$Algorithm_Norm.CoinName -Default 'auto')"
            }
            else {$Pers = ""}

            #Get commands for active miner devices
            $Params = <#temp fix#> Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index

            #define stratum
            switch ($Main_Algorithm -replace "2gb" -replace "3gb") {
                "equihash"     {$Stratum = "stratum$(if ($Pools.$Main_Algorithm_Norm.SSL) {'+ssl'})"}
                "equihash1445" {$Stratum = "equihash1445$(if ($Pools.$Main_Algorithm_Norm.SSL) {'+ssl'})"}
                "ethash"       {if ($Pools.$Main_Algorithm_Norm.Protocol -match "^stratum.+") {$Stratum = "ethstratum"} else {$Stratum = "ethash"}}
                "tensority"    {$Stratum = "tensority$(if ($Pools.$Main_Algorithm_Norm.SSL) {'+ssl'})"}
                "aeternity"    {$Stratum = "aeternity"}
                default        {$Stratum = $Main_Algorithm -replace "2gb" -replace "3gb"}
            }

            if ($_.SecondaryAlgorithm) { 
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                if ($Config.UseDeviceNameForStatsFileNaming) {
                    $Miner_Name = (@($Name) + @("$($Main_Algorithm_Norm)$($Secondary_Algorithm_Norm)$(if ($_.DualSubsolver -ge 0) {"-DS$($_.DualSubsolver)"})$(if ($_.SecondaryIntensity) {"-Intensity$($_.SecondaryIntensity)"})") + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
                }
                else {
                    $Miner_Name = (@($Name) + @("$($Main_Algorithm_Norm)$Secondary_Algorithm_Norm") + @(if ($_.DualSubsolver -ge 0) {"DS$($_.DualSubsolver)"}) + @(if ($_.SecondaryIntensity) {"Intensity$($_.SecondaryIntensity)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                }
                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; "$Secondary_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 1.3 / 100; $Secondary_Algorithm_Norm = 0 / 100} # Fixed at 1.3%, secondary algo no fee

                $Arguments_Secondary = " -uri2 $($Secondary_Algorithm)$(if ($Pools.$Main_Algorithm_Norm.SSL) {'+ssl'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.Pass))@$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port)$(if($_.SecondaryIntensity -ge 0){" -dual-intensity $($_.SecondaryIntensity)"})$(if($_.DualSubsolver -ge 0){" -dual-subsolver $($_.DualSubsolver)"})"

                if ($_.DualSubsolver -eq $null -or $_.SecondaryIntensity -eq $null) { #In auto tuning mode it takes a while until the secondary algo reports hash rates
                    $BenchmarkIntervals = 5
                    $WarmupTime = 300
                } 
                else {
                    $BenchmarkIntervals = 2
                    $WarmupTime = 120
                }
            }
            else {
                if ($Config.UseDeviceNameForStatsFileNaming) {
                    $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
                }
                else {
                    $Miner_Name = ((@($Name) + @($Main_Algorithm_Norm) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"
                }
                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}

                if ($Main_Algorithm_Norm -like "Ethash*") {$MinerFeeInPercent = 0.65} # Ethash fee fixed at 0.65%
                else {$MinerFeeInPercent = 2} # Other algos fee fixed at 2%

                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = $MinerFeeInPercent / 100}

                $BenchmarkIntervals = 1
                $WarmupTime = $null
            }

            if (-not ($Main_Algorithm_Norm -eq "Equihash1445" -and $Pools.Decred.Name -eq "NiceHash")) { #temp fix. Bminer is not compatible with decred on Nicehash, https://bitcointalk.org/index.php?topic=2519271.msg44083414#msg44083414
                [PSCustomObject]@{
                    Name               = $Miner_Name
                    DeviceName         = $Miner_Device.Name
                    Path               = $Path
                    HashSHA256         = $HashSHA256
                    Arguments          = ("-api 127.0.0.1:$($Miner_Port) $Pers -uri $($Stratum)://$([System.Web.HttpUtility]::UrlEncode($Pools.$Main_Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Main_Algorithm_Norm.Pass))@$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port)$Arguments_Secondary$Params$CommonCommands -devices $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                    HashRates          = $Miner_HashRates
                    API                = "Bminer"
                    Port               = $Miner_Port
                    URI                = $URI
                    Fees               = $Miner_Fees
                    BenchmarkIntervals = $BenchmarkIntervals
                    WarmupTime         = $WarmupTime
                }
            }
        }
    }
}
