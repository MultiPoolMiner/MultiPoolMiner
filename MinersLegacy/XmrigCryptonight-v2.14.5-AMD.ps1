using module ..\Include.psm1

#XmRig AMD / Nvidia requires the explicit use of detailled thread information in the config file
#these values are different for each card model and algorithm
#API will check for hw change and briefly start miner with an incomplete dummy config
#The miner binary it will add the thread element for all installed cards to the config file on first start
#Once this file is current we can retrieve the threads info

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\xmrig-amd.exe"
$HashSHA256 = "CC1ADF9337DB6F5646ADAA55B2BFB01B7FEB5FE4D3BB8884880E5BC30501B0F9"
$Uri = "https://github.com/xmrig/xmrig-amd/releases/download/v2.14.5/xmrig-amd-2.14.5-msvc-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig-amd"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit the config file in the miner binary directory
    #       'Config-[Pool]_[Algorithm_Norm]-[Port]-[User]-[Pass].json'
    [PSCustomObject]@{Algorithm = "Cryptonight/0";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # Cryptonight    
    [PSCustomObject]@{Algorithm = "Cryptonight/1";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightV7
    [PSCustomObject]@{Algorithm = "Cryptonight/2";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=2 --opencl-mem-chunk=1"} # CryptonightV8, new with 2.8.1
    [PSCustomObject]@{Algorithm = "Cryptonight/double";     MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightDoubleV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/gpu";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{Algorithm = "Cryptonight/half";       MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightHalfV8, new with 2.9.1
    [PSCustomObject]@{Algorithm = "Cryptonight/msr";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightMsr
    [PSCustomObject]@{Algorithm = "Cryptonight/1";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightV7
    [PSCustomObject]@{Algorithm = "Cryptonight/r";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightR, new with 2.13.0
    [PSCustomObject]@{Algorithm = "Cryptonight/rto";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightRto
    [PSCustomObject]@{Algorithm = "Cryptonight/rwz";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightRwzV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/trtl";       MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightTrtl, new with 2.10.0
    [PSCustomObject]@{Algorithm = "Cryptonight/xao";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightXao
    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightXtl
    [PSCustomObject]@{Algorithm = "Cryptonight/zls";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightZls, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";     MinMemGB = 1; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightLite
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";     MinMemGB = 1; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightLiteV7
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";     MinMemGB = 1; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightLiteV8
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";      MinMemGB = 4; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightHeavy
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube"; MinMemGB = 4; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightHeavyTube
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";  MinMemGB = 4; Threads = 1; Command = " --opencl-strided-index=1"} # CryptonightHeavyHaven
    [PSCustomObject]@{Algorithm = "Cryptonight/0";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # Cryptonight    
    [PSCustomObject]@{Algorithm = "Cryptonight/1";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightV7
    [PSCustomObject]@{Algorithm = "Cryptonight/2";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=2 --opencl-mem-chunk=1"} # CryptonightV8, new with 2.8.1
    [PSCustomObject]@{Algorithm = "Cryptonight/gpu";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightDoubleV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/double";     MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{Algorithm = "Cryptonight/half";       MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightHalfV8, new with 2.9.1
    [PSCustomObject]@{Algorithm = "Cryptonight/msr";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightMsr
    [PSCustomObject]@{Algorithm = "Cryptonight/r";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightR, new with 2.13.0
    [PSCustomObject]@{Algorithm = "Cryptonight/rto";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightRto
    [PSCustomObject]@{Algorithm = "Cryptonight/rwz";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightRwzV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/trtl";       MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightTrtl, new with 2.10.0
    [PSCustomObject]@{Algorithm = "Cryptonight/xao";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightXao
    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightXtl
    [PSCustomObject]@{Algorithm = "Cryptonight/zls";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightZls, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";     MinMemGB = 1; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightLite
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";     MinMemGB = 1; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightLiteV7
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";     MinMemGB = 1; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightLiteV8
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";      MinMemGB = 4; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightHeavy
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube"; MinMemGB = 4; Threads = 2; Command = " --opencl-strided-index=1"} # CryptonightHeavyTube
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";  MinMemGB = 4; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightHeavyHaven
    [PSCustomObject]@{Algorithm = "Cryptonight/0";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # Cryptonight    
    [PSCustomObject]@{Algorithm = "Cryptonight/1";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightV7
    [PSCustomObject]@{Algorithm = "Cryptonight/2";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=2 --opencl-mem-chunk=1"} # CryptonightV8, new with 2.8.1
    [PSCustomObject]@{Algorithm = "Cryptonight/double";     MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightDoubleV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/gpu";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{Algorithm = "Cryptonight/half";       MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightHalfV8, new with 2.9.1
    [PSCustomObject]@{Algorithm = "Cryptonight/msr";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightMsr
    [PSCustomObject]@{Algorithm = "Cryptonight/r";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightR, new with 2.13.0
    [PSCustomObject]@{Algorithm = "Cryptonight/rto";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightRto
    [PSCustomObject]@{Algorithm = "Cryptonight/rwz";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightRwzV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/trtl";       MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightTrtl, new with 2.10.0
    [PSCustomObject]@{Algorithm = "Cryptonight/xao";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightXao
    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightXtl
    [PSCustomObject]@{Algorithm = "Cryptonight/zls";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightZls, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";     MinMemGB = 1; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightLite
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";     MinMemGB = 1; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightLiteV7
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";     MinMemGB = 1; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightLiteV8
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";      MinMemGB = 4; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightHeavy
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube"; MinMemGB = 4; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightHeavyTube
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";  MinMemGB = 4; Threads = 3; Command = " --opencl-strided-index=1"} # CryptonightHeavyHaven
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB * $Threads
        $Threads = $_.Threads

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '-') + @($Threads) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '-') + @($Miner_Port) + @($Threads) | Select-Object) -join '-').json"
            $ThreadsConfigFileName = "$((@("ThreadsConfig") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '-') | Select-Object) -join '-').json"
            $PoolParameters = " --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --userpass=$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass) --keepalive$(if ($Pools.$Algorithm_Norm.Name -eq 'Nicehash') {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"

            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content  = [PSCustomObject]@{
                        "algo"            = $Algorithm
                        "api" = [PSCustomObject]@{
                            "port"         = $Miner_Port
                            "access-token" = $null
                            "worker-id"    = $null
                        }
                        "background"      = $false
                        "cache"           = $true
                        "colors"          = $true
                        "donate-level"    = 1
                        "log-file"        = $null
                        "print-time"      = 5
                        "retries"         = 5
                        "retry-pause"     = 5
                        "opencl-platform" = ($Miner_Device.PlatformId | Select-Object -Unique)
                    }
                }
                Commands = ("$Command$CommonCommands$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"}) --config=$ConfigFileName --opencl-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HwDetectCommands = "$Command$CommonCommands$PoolParameters --config=$ThreadsConfigFileName"
                Devices = @($Miner_Device.Type_Vendor_Index)
                Threads = $Threads
                ThreadsConfigFileName = $ThreadsConfigFileName
            }

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
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
