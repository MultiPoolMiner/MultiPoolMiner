using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\PhoenixMiner.exe"
$HashSHA256 = "224E4EBB1AFCA88B973F3194EEDAE529DA206928CC64267A3EB10AB0D7DB909E"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/phoenixminer/PhoenixMiner_4.0b_Windows.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"
$Port = "40{0:d2}"

#DualMining does not work with 4.0b
$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "";        SecondaryIntensity = 00; Params = ""} #Ethash2GB
#    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 30; Params = ""} #Ethash2gb/Blake2s10
#    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash2gb/Blake2s20
#    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 90; Params = ""} #Ethash2gb/Blake2s30
#    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 120; Params = ""} #Ethash2gb/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "";        SecondaryIntensity = 00; Params = ""} #Ethash3GB
#    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 30; Params = ""} #Ethash3gb/Blake2s10
#    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash3gb/Blake2s20
#    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 90; Params = ""} #Ethash3gb/Blake2s30
#    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 120; Params = ""} #Ethash3gb/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "";        SecondaryIntensity = 00; Params = ""} #Ethash
#    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 30; Params = ""} #Ethash/Blake2s10
#    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s20
#    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 90; Params = ""} #Ethash/Blake2s30
#    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 120; Params = ""} #Ethash/Blake2s40
)
$CommonCommandsAll    = " -log 0 -wdog 0"
$CommonCommandsNvidia = " -mi 14"
$CommonCommandsAmd    = " -gt 0" #Enable auto-tuning

$Devices = @($Devices | Where-Object Type -EQ "GPU")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {
            $CommonCommands = $CommonCommandsAmd + $CommonCommandsAll
            $Vendor = "AMD"
        }
        "NVIDIA Corporation" {
            $CommonCommands = $CommonCommandsNvidia + $CommonCommandsAll
            $Vendor = "NVIDIA"
        }
        Default {
            $CommonCommands = $CommonCommandsAll
        }
    }

    $Commands | Where-Object {$Vendor -eq "AMD" -or -not $_.SecondaryAlgorithm} | ForEach-Object { #Dual mining is only supported for AMD
        $Main_Algorithm = $_.MainAlgorithm
        $Main_Algorithm_Norm = Get-Algorithm $Main_Algorithm
        $MinMemGB = $_.MinMemGB

        $Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})

        if ($Pools.$Main_Algorithm_Norm.Host -and $Miner_Device) {
            #Get commands for active miner devices
            $Params = <#temp fix#> Get-CommandPerDevice $_.Params $Miner_Device.Type_Index

            if ($_.SecondaryAlgorithm) {
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                if ($Config.UseDeviceNameForStatsFileNaming) {
                    $Miner_Name = (@($Name) + @("$(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_')-$Main_Algorithm_Norm$Secondary_Algorithm_Norm-$(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity})") | Select-Object) -join '-'
                }
                else {
                    $Miner_Name = ((@($Name) + @("$($Main_Algorithm_Norm -replace '^ethash', '')$Secondary_Algorithm_Norm") + @(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"
                }

                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; "$Secondary_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary = " -dcoin $Secondary_Algorithm -dpool $(if ($Pools.$Secondary_Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpass $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -sci $($_.SecondaryIntensity)"})"
                $BenchmarkIntervals = 2
                $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0.9 / 100; "$Secondary_Algorithm_Norm" = 0 / 100}
            }
            else {
                if ($Config.UseDeviceNameForStatsFileNaming) {
                    $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
                }
                else {
                    $Miner_Name = ((@($Name) + @("$($Main_Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"
                }

                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary = ""
                if ($CommonCommands -match " -gt 0" ) {$BenchmarkIntervals = 2} else {$BenchmarkIntervals = 1}
                $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0.65 / 100}
            }

            [PSCustomObject]@{
                Name               = $Miner_Name
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("-mport -$Miner_Port$(if($Pools.$Main_Algorithm_Norm.Name -eq "NiceHash") {" -proto 4"} else {" -proto 1"}) -pool $(if ($Pools.$Main_Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -wal $($Pools.$Main_Algorithm_Norm.User) -pass $($Pools.$Main_Algorithm_Norm.Pass)$Arguments_Secondary$Params$CommonCommands -gpus $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Index + 1)}) -join ',')" -replace "\s+", " ").trim()
                HashRates          = $Miner_HashRates
                API                = "Claymore"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = $Miner_Fees
                BenchmarkIntervals = $BenchmarkIntervals
            }
        }
    }
}
