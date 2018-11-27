using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\excavator.exe"
$HashSHA256 = "4CC2FF8C07F17E940A1965B8D0F7DD8508096A4E4928704912FA96C442346642"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.4.4a/excavator_v1.4.4a_NVIDIA_Win64.zip"
$Port = "5400"

$Commands = [PSCustomObject[]]@(
    #1 Thread
    [PSCustomObject]@{Algorithm = "daggerhashimoto";        Threads = 1; MinMemGB = 2;     BenchmarkIntervals = 1; Params = @()} #Ethash
    [PSCustomObject]@{Algorithm = "equihash";               Threads = 1; MinMemGB = 2;     BenchmarkIntervals = 1; Params = @()} #Equihash
    [PSCustomObject]@{Algorithm = "lyra2rev2";              Threads = 1; MinMemGB = 1;     BenchmarkIntervals = 1; Params = @()} #Lyra2RE2
    [PSCustomObject]@{Algorithm = "neoscrypt";              Threads = 1; MinMemGB = 2;     BenchmarkIntervals = 1; Params = @()} #NeoScrypt
    [PSCustomObject]@{Algorithm = "daggerhashimoto_decred"; Threads = 1; MinMemGB = 3;     BenchmarkIntervals = 2; Params = @()} #Dual mining 1 thread
    [PSCustomObject]@{Algorithm = "daggerhashimoto_pascal"; Threads = 1; MinMemGB = 3;     BenchmarkIntervals = 2; Params = @()} #Dual mining 1 thread
    [PSCustomObject]@{Algorithm = "daggerhashimoto_sia";    Threads = 1; MinMemGB = 3;     BenchmarkIntervals = 2; Params = @()} #Dual mining 1 thread

    #2 Threads
    [PSCustomObject]@{Algorithm = "daggerhashimoto";        Threads = 2; MinMemGB = 2*3.5; BenchmarkIntervals = 1; Params = @()} #Ethash
    [PSCustomObject]@{Algorithm = "equihash";               Threads = 2; MinMemGB = 2*2;   BenchmarkIntervals = 1; Params = @()} #Equihash
    [PSCustomObject]@{Algorithm = "lyra2rev2";              Threads = 2; MinMemGB = 1*2;   BenchmarkIntervals = 1; Params = @()} #Lyra2RE2
    #[PSCustomObject]@{Algorithm = "neoscrypt";              Threads = 2; MinMemGB = 2*2;   BenchmarkIntervals = 1; Params = @()} #NeoScrypt 2threads crashes
    [PSCustomObject]@{Algorithm = "daggerhashimoto_decred"; Threads = 2; MinMemGB = 2*3.5; BenchmarkIntervals = 2; Params = @()} #Dual mining 2 threads
    [PSCustomObject]@{Algorithm = "daggerhashimoto_pascal"; Threads = 2; MinMemGB = 2*3.5; BenchmarkIntervals = 2; Params = @()} #Dual mining 2 threads
    [PSCustomObject]@{Algorithm = "daggerhashimoto_sia";    Threads = 2; MinMemGB = 2*3.5; BenchmarkIntervals = 2; Params = @()} #Dual mining 2 threads

    #ASIC mining only 14/08/2018
    #[PSCustomObject]@{Algorithm = "decred";                 Threads = 1; MinMemGB = 1;     BenchmarkIntervals = 1; Params = @()} #DecredNicehash
    #[PSCustomObject]@{Algorithm = "lbry";                   Threads = 1; MinMemGB = 2;     BenchmarkIntervals = 1; Params = @()} #Lbry
    #[PSCustomObject]@{Algorithm = "pascal";                 Threads = 1; MinMemGB = 1;     BenchmarkIntervals = 1; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "sia";                    Threads = 1; MinMemGB = 1;     BenchmarkIntervals = 1; Params = @()} #Sia
)

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Main_Algorithm = $Algorithm -Split "_" | Select-Object -Index 0
        $Main_Algorithm_Norm = Get-Algorithm $Main_Algorithm
        $Secondary_Algorithm = $Algorithm -Split "_" | Select-Object -Index 1
        $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm
        if ($Secondary_Algorithm -eq "decred") {$Secondary_Algorithm_Norm = "DecredNicehash"} #temp fix
        $Threads = $_.Threads
        $Params = $_.Params
        $MinMemGB = $_.MinMemGB

        $Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})

        if ($Pools.$Main_Algorithm_Norm.Host -and $Miner_Device) {
            if (-not $Secondary_Algorithm) {
                #Single algo mining
                if ($Config.UseDeviceNameForStatsFileNaming) {
                    $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @($Threads) | Select-Object) -join '-'
                }
                else {
                    $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                }

                [PSCustomObject]@{
                    Name               = $Miner_Name
                    DeviceName         = $Miner_Device.Name
                    Path               = $Path
                    HashSHA256         = $HashSHA256
                    Arguments          = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm", "$([Net.DNS]::Resolve($Pools.$Main_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Main_Algorithm_Norm.Port)", "$($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)")}) + @([PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_PlatformId_Index | ForEach-Object {@("alg-0", "$_")} | Select-Object) * $Threads) + $Params})
                    HashRates          = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                    API                = "Excavator"
                    Port               = $Miner_Port
                    URI                = $Uri
                    BenchmarkIntervals = $BenchmarkIntervals
                    PrerequisitePath   = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI    = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                }
            }
            else {
                #Dual algo mining
                if ($Pools.$Secondary_Algorithm_Norm.Host ) {
                    if ($Config.UseDeviceNameForStatsFileNaming) {
                        $Miner_Name = (@($Name) + @("$(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_')$($Main_Algorithm_Norm)$($Secondary_Algorithm_Norm -replace 'Nicehash')") + @($Threads) | Select-Object) -join '-'
                    }
                    else {
                        $Miner_Name = (@($Name) + @("$Secondary_Algorithm_Norm" -replace "Nicehash") + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    }

                    [PSCustomObject]@{
                        Name               = $Miner_Name
                        DeviceName         = $Miner_Device.Name
                        Path               = $Path
                        HashSHA256         = $HashSHA256
                        Arguments          = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Algorithm", "$([Net.DNS]::Resolve($Pools.$Main_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Main_Algorithm_Norm.Port)", "$($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)", "$([Net.DNS]::Resolve($Pools.$Secondary_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Secondary_Algorithm_Norm.Port)", "$($Pools.$Secondary_Algorithm_Norm.User):$($Pools.$Secondary_Algorithm_Norm.Pass)")}) + @([PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_PlatformId_Index | ForEach-Object {@("alg-0", "$_")} | Select-Object) * $Threads) + $Params})
                        HashRates          = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                        API                = "Excavator"
                        Port               = $Miner_Port
                        URI                = $Uri
                        BenchmarkIntervals = $BenchmarkIntervals
                        PrerequisitePath   = "$env:SystemRoot\System32\msvcr120.dll"
                        PrerequisiteURI    = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                    }
                }
            }
        }
    }
}
