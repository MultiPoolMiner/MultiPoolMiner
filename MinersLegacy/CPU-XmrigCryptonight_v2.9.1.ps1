using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\xmrig.exe"
$HashSHA256 = "7448B62DCF40B7488328ECEAC0BC9124A37A735F331955BF3D991A573056F308"
$Uri = "https://github.com/xmrig/xmrig/releases/download/v2.9.1/xmrig-2.9.1-msvc-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig"

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit [Pool]_[Algorithm]-[Port]-[User]-[Pass].json in the miner binary directory 
    [PSCustomObject]@{Algorithm = "Cryptonight/0";           MinMemGB = 2; Threads = 1; Params = ""} # Cryptonight    
    [PSCustomObject]@{Algorithm = "Cryptonight/1";           MinMemGB = 2; Threads = 1; Params = ""} # CryptonightV7
    [PSCustomObject]@{Algorithm = "Cryptonight/2";           MinMemGB = 2; Threads = 1; Params = ""} # CryptonightV8, new with 2.8.1
    [PSCustomObject]@{Algorithm = "Cryptonight/half";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightHalf, new with 2.9.1
    [PSCustomObject]@{Algorithm = "Cryptonight/msr";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightMsr
    [PSCustomObject]@{Algorithm = "Cryptonight/rto";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightRto
    [PSCustomObject]@{Algorithm = "Cryptonight/xao";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightXao
    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightXtl
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";      MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLite
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";      MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLiteV7
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";      MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLiteV8
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";       MinMemGB = 4; Threads = 1; Params = ""} # CryptonightHeavy
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube";  MinMemGB = 4; Threads = 1; Params = ""} # CryptonightHeavyTube
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";   MinMemGB = 4; Threads = 1; Params = ""} # CryptonightHeavyHaven
#    [PSCustomObject]@{Algorithm = "Cryptonight/0";           MinMemGB = 2; Threads = 2; Params = ""} # Cryptonight  
#    [PSCustomObject]@{Algorithm = "Cryptonight/1";           MinMemGB = 2; Threads = 2; Params = ""} # CryptonightV7
#    [PSCustomObject]@{Algorithm = "Cryptonight/2";           MinMemGB = 2; Threads = 2; Params = ""} # CryptonightV8, new with 2.8.1
#    [PSCustomObject]@{Algorithm = "Cryptonight/half";        MinMemGB = 2; Threads = 2; Params = ""} # CryptonightHalf, new with 2.9.1
#    [PSCustomObject]@{Algorithm = "Cryptonight/msr";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightMsr
#    [PSCustomObject]@{Algorithm = "Cryptonight/rto";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightRto
#    [PSCustomObject]@{Algorithm = "Cryptonight/xao";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightXao
#    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightXtl
#    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";      MinMemGB = 1; Threads = 2; Params = ""} # CryptonightLite
#    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";      MinMemGB = 1; Threads = 2; Params = ""} # CryptonightLiteV7
#    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";      MinMemGB = 1; Threads = 2; Params = ""} # CryptonightLiteV8
#    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";       MinMemGB = 4; Threads = 2; Params = ""} # CryptonightHeavy
#    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube";  MinMemGB = 4; Threads = 2; Params = ""} # CryptonightHeavyTube
#    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";   MinMemGB = 4; Threads = 2; Params = ""} # CryptonightHeavyHaven
)
$CommonCommands = ""

$Devices = @($Devices | Where-Object Type -EQ "CPU")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 3   

    $Commands | ForEach-Object {

        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $Params = $_.Params
        $Threads = $_.Threads

        if ($Miner_Device) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @($Threads) | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object)  + @($Threads) | Select-Object) -join '-'
            }

            #Get commands for active miner devices
            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @($Miner_Device.Model_Norm -Join "_") + @($Miner_Port) + @($Threads) | Select-Object) -join '-').json"
            $ThreadsConfigFileName = "$((@("ThreadsConfig") + @($Algorithm_Norm) + @($Devices.Model_Norm -Join "_") | Select-Object) -join '-').json"
            $PoolParameters = "--url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --userpass=$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass) --keepalive$(if ($Pools.$Algorithm_Norm.Name -eq 'Nicehash') {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"

            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content = [PSCustomObject]@{
                        "algo"         = $Algorithm
                        "api" = [PSCustomObject]@{
                            "port"         = $Miner_Port
                            "access-token" = $null
                            "worker-id"    = $null
                        }
                        "background"   = $false
                        "cuda-bfactor" = 10
                        "colors"       = $true
                        "donate-level" = 1
                        "log-file"     = $null
                        "print-time"   = 5
                        "retries"      = 5
                        "retry-pause"  = 5
                    }
                }
                Commands = ("$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"}) --config=$ConfigFileName$(Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index)$CommonCommands" -replace "\s+", " ").trim()
                ThreadsConfigFileName = $ThreadsConfigFileName
                Threads = $Threads * (($Miner_Device.CIM | Measure-Object ThreadCount -Minimum).Minimum -1)
                HwDetectCommands = "$PoolParameters --config=$ThreadsConfigFileName$Params$CommonCommands"
            }
            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Arguments
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "XmRig"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            }
        }
    }
}
