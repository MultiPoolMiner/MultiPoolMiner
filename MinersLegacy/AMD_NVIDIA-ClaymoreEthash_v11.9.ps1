using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\EthDcrMiner64.exe"
$HashSHA256 = "4A9AC40A4E8C2F59683294726616A1BE7DE6A78B4929AC490D6844C2CB69E347"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/ClaymoreDual_v11.9.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=1433925.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash2gb
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Blake2s20
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Blake2s60
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80;  Params = ""} #Ethash2gb/Blake2s80
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Decred20
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Decred40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 70;  Params = ""} #Ethash2gb/Decred70
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 100; Params = ""} #Ethash2gb/Decred100
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Keccak20
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 30;  Params = ""} #Ethash2gb/Keccak30
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Keccak40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Lbry40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Lbry60
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 75;  Params = ""} #Ethash2gb/Lbry75
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 90;  Params = ""} #Ethash2gb/Lbry90
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Pascal20
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Pascal40
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Pascal60
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 80;  Params = ""} #Ethash2gb/Pascal80
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash3gb
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Blake2s20
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Blake2s60
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80;  Params = ""} #Ethash3gb/Blake2s80
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Decred20
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Decred40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  SecondaryIntensity = 70;  Params = ""} #Ethash3gb/Decred70
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  SecondaryIntensity = 100; Params = ""} #Ethash3gb/Decred100
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Keccak20
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 30;  Params = ""} #Ethash3gb/Keccak30
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Keccak40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Lbry40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Lbry60
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 75;  Params = ""} #Ethash3gb/Lbry75
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 90;  Params = ""} #Ethash3gb/Lbry90
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Pascal20
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Pascal40
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Pascal60
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 80;  Params = ""} #Ethash3gb/Pascal80
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 20;  Params = ""} #Ethash/Blake2s20
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40;  Params = ""} #Ethash/Blake2s40
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash/Blake2s60
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80;  Params = ""} #Ethash/Blake2s80
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 20;  Params = ""} #Ethash/Decred20
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 40;  Params = ""} #Ethash/Decred40
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 70;  Params = ""} #Ethash/Decred70
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 100; Params = ""} #Ethash/Decred100
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 20;  Params = ""} #Ethash/Keccak20
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 30;  Params = ""} #Ethash/Keccak30
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 40;  Params = ""} #Ethash/Keccak40
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 40;  Params = ""} #Ethash/Lbry40
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 60;  Params = ""} #Ethash/Lbry60
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 75;  Params = ""} #Ethash/Lbry75
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 90;  Params = ""} #Ethash/Lbry90
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 20;  Params = ""} #Ethash/Pascal20
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 40;  Params = ""} #Ethash/Pascal40
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 60;  Params = ""} #Ethash/Pascal60
    [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 80;  Params = ""} #Ethash/Pascal80
)
$CommonCommands = " -dbg -1"

$Devices = @($Devices | Where-Object Type -EQ "GPU")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {$Arguments_Platform = " -platform 1 -y 1"}
        "NVIDIA Corporation" {$Arguments_Platform = " -platform 2"}
        Default {$Arguments_Platform = ""}
    }

    $Commands | ForEach-Object {
        $Main_Algorithm = $_.MainAlgorithm
        $Main_Algorithm_Norm = Get-Algorithm $Main_Algorithm
        $Params = $_.Params
        $MinMemGB = $_.MinMemGB

        $Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})

        if ($Pools.$Main_Algorithm_Norm.Host -and $Arguments_Platform -and $Miner_Device) {

            #Get commands for active miner devices
            $Params = Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index

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
                $Arguments_Secondary = " -dcoin $Secondary_Algorithm -dpool $($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpsw $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -dcri $($_.SecondaryIntensity)"})"
                $BenchmarkIntervals = 2

                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 1GB}) {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 1.5 / 100; "$Secondary_Algorithm_Norm" = 0 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0 / 100; "$Secondary_Algorithm_Norm" = 0 / 100}
                }
            }
            else {
                if ($Config.UseDeviceNameForStatsFileNaming) {
                    $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @($Main_Algorithm_Norm) | Select-Object) -join '-'
                }
                else {
                    $Miner_Name = ((@($Name) + @("$($Main_Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"
                }

                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}

                $Arguments_Secondary = ""
                $BenchmarkIntervals = 1

                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 2GB}) {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 1 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0 / 100}
                }
            }

            [PSCustomObject]@{
                Name               = $Miner_Name
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("-mport -$Miner_Port -epool $($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -ewal $($Pools.$Main_Algorithm_Norm.User) -epsw $($Pools.$Main_Algorithm_Norm.Pass) -allpools 1 -allcoins exp -esm 3$Arguments_Secondary$Params$CommonCommands$Arguments_Platform -di $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
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
