using module ..\Include.psm1

#XmRig AMD / Nvidia requires the explicit use of detailled thread information in the config file
#these values are different for each card model and algorithm
#API will check for hw change and briefly start miner with an incomplete dummy config
#The miner binary will add the thread element(s) to the config file on first start for all installed cards 
#Once this file is current we can retrieve the threads info

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\xmrig-amd.exe"
$HashSHA256 = "A2B3FCED3BA1A10E7E86CBED089F9D8B7706287EE9F992AD7CE45FFFEB123D04"
$Uri = "https://github.com/xmrig/xmrig-amd/releases/download/v2.14.6/xmrig-amd-2.14.6-msvc-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig-amd"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) { $Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*" }

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD")

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit the config file in the miner binary directory
    #       'Config-[Pool]_[Algorithm_Norm]-[GPU-List]-[Port].json'
    [PSCustomObject]@{ Algorithm = "cn/0";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # Cryptonight
    [PSCustomObject]@{ Algorithm = "cn/1";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightV1
    [PSCustomObject]@{ Algorithm = "cn/2";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=2 --opencl-mem-chunk=1" } # CryptonightV2, new with 2.8.1
    [PSCustomObject]@{ Algorithm = "cn/double";     MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightDouble, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn/gpu";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{ Algorithm = "cn/half";       MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightHalf, new with 2.9.1
    [PSCustomObject]@{ Algorithm = "cn/msr";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightMsr
    [PSCustomObject]@{ Algorithm = "cn/r";          MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightR, new with 2.13.0
    [PSCustomObject]@{ Algorithm = "cn/rto";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightRto
    [PSCustomObject]@{ Algorithm = "cn/rwz";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightRwz, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn/trtl";       MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightTurtle, new with 2.10.0
    [PSCustomObject]@{ Algorithm = "cn/xao";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightXao
    [PSCustomObject]@{ Algorithm = "cn/xtl";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightXtl
    [PSCustomObject]@{ Algorithm = "cn/zls";        MinMemGB = 2; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightZls, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn-lite/0";     MinMemGB = 1; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightLite
    [PSCustomObject]@{ Algorithm = "cn-lite/1";     MinMemGB = 1; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightLiteV1
    [PSCustomObject]@{ Algorithm = "cn-heavy";      MinMemGB = 4; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightHeavy
    [PSCustomObject]@{ Algorithm = "cn-heavy/tube"; MinMemGB = 4; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightHeavyTube
    [PSCustomObject]@{ Algorithm = "cn-heavy/xhv";  MinMemGB = 4; Threads = 1; Command = " --opencl-strided-index=1" } # CryptonightHeavyXhv

    [PSCustomObject]@{ Algorithm = "cn/0";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # Cryptonight
    [PSCustomObject]@{ Algorithm = "cn/1";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightV1
    [PSCustomObject]@{ Algorithm = "cn/2";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=2 --opencl-mem-chunk=1" } # CryptonightV2, new with 2.8.1
    [PSCustomObject]@{ Algorithm = "cn/double";     MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightDouble, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn/gpu";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{ Algorithm = "cn/half";       MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightHalfV8, new with 2.9.1
    [PSCustomObject]@{ Algorithm = "cn/msr";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightMsr
    [PSCustomObject]@{ Algorithm = "cn/r";          MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightR, new with 2.13.0
    [PSCustomObject]@{ Algorithm = "cn/rto";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightRto
    [PSCustomObject]@{ Algorithm = "cn/rwz";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightRwz, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn/trtl";       MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightTurtle, new with 2.10.0
    [PSCustomObject]@{ Algorithm = "cn/xao";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightXao
    [PSCustomObject]@{ Algorithm = "cn/xtl";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightXtl
    [PSCustomObject]@{ Algorithm = "cn/zls";        MinMemGB = 2; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightZls, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn-lite/0";     MinMemGB = 1; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightLite
    [PSCustomObject]@{ Algorithm = "cn-lite/1";     MinMemGB = 1; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightLiteV1
    [PSCustomObject]@{ Algorithm = "cn-heavy";      MinMemGB = 4; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightHeavy
    [PSCustomObject]@{ Algorithm = "cn-heavy/tube"; MinMemGB = 4; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightHeavyTube
    [PSCustomObject]@{ Algorithm = "cn-heavy/xhv";  MinMemGB = 4; Threads = 2; Command = " --opencl-strided-index=1" } # CryptonightHeavyXhv

    [PSCustomObject]@{ Algorithm = "cn/0";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # Cryptonight
    [PSCustomObject]@{ Algorithm = "cn/1";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightV1
    [PSCustomObject]@{ Algorithm = "cn/2";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=2 --opencl-mem-chunk=1" } # CryptonightV1, new with 2.8.1
    [PSCustomObject]@{ Algorithm = "cn/double";     MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightDouble, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn/gpu";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{ Algorithm = "cn/half";       MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightHalfV8, new with 2.9.1
    [PSCustomObject]@{ Algorithm = "cn/msr";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightMsr
    [PSCustomObject]@{ Algorithm = "cn/r";          MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightR, new with 2.13.0
    [PSCustomObject]@{ Algorithm = "cn/rto";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightRto
    [PSCustomObject]@{ Algorithm = "cn/rwz";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightRwz, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn/trtl";       MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightTurtle, new with 2.10.0
    [PSCustomObject]@{ Algorithm = "cn/xao";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightXao
    [PSCustomObject]@{ Algorithm = "cn/xtl";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightXtl
    [PSCustomObject]@{ Algorithm = "cn/zls";        MinMemGB = 2; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightZls, new with 2.14.0
    [PSCustomObject]@{ Algorithm = "cn-lite/0";     MinMemGB = 1; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightLite
    [PSCustomObject]@{ Algorithm = "cn-lite/1";     MinMemGB = 1; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightLiteV1
    [PSCustomObject]@{ Algorithm = "cn-heavy";      MinMemGB = 4; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightHeavy
    [PSCustomObject]@{ Algorithm = "cn-heavy/tube"; MinMemGB = 4; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightHeavyTube
    [PSCustomObject]@{ Algorithm = "cn-heavy/xhv";  MinMemGB = 4; Threads = 3; Command = " --opencl-strided-index=1" } # CryptonightHeavyXhv
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB * $_.Threads

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @(($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) -join '-') + @($_.Threads) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model | Sort-Object -unique | Sort-Object Name | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model($(($Miner_Device | Sort-Object Name | Where-Object Model -eq $Model).Name -join ';'))" } | Select-Object) -join '-') + @($Miner_Port) + @($_.Threads) | Select-Object) -join '-').json"
            $ThreadsConfigFileName = "$((@("ThreadsConfig") + @($Algorithm_Norm) + @(($Miner_Device.Model | Sort-Object -unique | Sort-Object Name | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model($(($Miner_Device | Sort-Object Name | Where-Object Model -eq $Model).Name -join ';'))" } | Select-Object) -join '-') | Select-Object) -join '-').json"
            $PoolParameters = " --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --userpass=$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass) --keepalive$(if ($Pools.$Algorithm_Norm.Name -eq 'Nicehash') { " --nicehash" })$(if ($Pools.$Algorithm_Norm.SSL) { " --tls" })"

            $Arguments = [PSCustomObject]@{ 
                ConfigFile = [PSCustomObject]@{ 
                    FileName = $ConfigFileName
                    Content  = [PSCustomObject]@{ 
                        "algo"            = $_.Algorithm
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
                Commands = ("$Command$CommonCommands$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) { " --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)" }) --config=$ConfigFileName --opencl-devices=$(($Miner_Device | ForEach-Object { '{0:x}' -f $_.Type_Vendor_Index }) -join ',')" -replace "\s+", " ").trim()
                HwDetectCommands = "$Command$CommonCommands$PoolParameters --config=$ThreadsConfigFileName"
                Devices = @($Miner_Device.Type_Vendor_Index)
                Threads = $_.Threads
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
                HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                API        = "XmRig"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{ $Algorithm_Norm = 1 / 100 }
             }
         }
     }
 }
