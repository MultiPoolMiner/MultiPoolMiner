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
$Path = ".\Bin\$($Name)\xmrig-nvidia.exe"
$ManualUri = "https://github.com/xmrig/xmrig-nvidia"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 9.2
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

if ($CUDAVersion -lt [System.Version]"10.0.0") {
    $HashSHA256 = "21BE7CCAFB7DE5DAD78686266B8A397FCD7BEFA4DE8546D0867A10A2F62D7A66"
    $Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.4/xmrig-nvidia-2.14.4-cuda9_2-win64.zip"
}
elseif ($CUDAVersion -lt [System.Version]"10.1.0") {
    $HashSHA256 = "24CEEF48F54893F4439143FBBA88B8EAE49BD43557666AE3DD9C29BCBD1BA92B"
    $Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.4/xmrig-nvidia-2.14.4-cuda10-win64.zip"
}
else {
    $HashSHA256 = "158EBFD4750A9FADA946E3528D8C2A9EDEC2FE674330CD66370C145AF4A655BE"
    $Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.4/xmrig-nvidia-2.14.4-cuda10_1-win64.zip"
}

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit [Pool]_[Algorithm]-[Port]-[User]-[Pass].json in the miner binary directory
    [PSCustomObject]@{Algorithm = "Cryptonight/0";          MinMemGB = 2; Threads = 1; Command = ""} # Cryptonight    
    [PSCustomObject]@{Algorithm = "Cryptonight/1";          MinMemGB = 2; Threads = 1; Command = ""} # CryptonightV7
    [PSCustomObject]@{Algorithm = "Cryptonight/2";          MinMemGB = 2; Threads = 1; Command = ""} # CryptonightV8, new with 2.8.0rc
    [PSCustomObject]@{Algorithm = "Cryptonight/double";     MinMemGB = 2; Threads = 1; Command = ""} # CryptonightDoubleV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/gpu";        MinMemGB = 2; Threads = 1; Command = ""} # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{Algorithm = "Cryptonight/half";       MinMemGB = 2; Threads = 1; Command = ""} # CryptonightHalfV8, new with 2.9.1
    [PSCustomObject]@{Algorithm = "Cryptonight/msr";        MinMemGB = 2; Threads = 1; Command = ""} # CryptonightMsr
    [PSCustomObject]@{Algorithm = "Cryptonight/r";          MinMemGB = 2; Threads = 1; Command = ""} # CryptonightR, new with 2.13.0
    [PSCustomObject]@{Algorithm = "Cryptonight/rto";        MinMemGB = 2; Threads = 1; Command = ""} # CryptonightRto
    [PSCustomObject]@{Algorithm = "Cryptonight/rwz";        MinMemGB = 2; Threads = 1; Command = ""} # CryptonightRwzV8, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight/trtl";       MinMemGB = 2; Threads = 1; Command = ""} # CryptonightTrtl, new with 2.10.0
    [PSCustomObject]@{Algorithm = "Cryptonight/xao";        MinMemGB = 2; Threads = 1; Command = ""} # CryptonightXao
    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";        MinMemGB = 2; Threads = 1; Command = ""} # CryptonightXtl
    [PSCustomObject]@{Algorithm = "Cryptonight/zls";        MinMemGB = 2; Threads = 1; Command = ""} # CryptonightZls, new with 2.14.0
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";     MinMemGB = 1; Threads = 1; Command = ""} # CryptonightLite
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";     MinMemGB = 1; Threads = 1; Command = ""} # CryptonightLiteV7
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";     MinMemGB = 1; Threads = 1; Command = ""} # CryptonightLiteV8
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";      MinMemGB = 2; Threads = 1; Command = ""} # CryptonightHeavy
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube"; MinMemGB = 2; Threads = 1; Command = ""} # CryptonightHeavyTube
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";  MinMemGB = 2; Threads = 1; Command = ""} # CryptonightHeavyHaven
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
        $MinMemGB = $_.MinMemGB * $_.Threads

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '-') + @($_.Threads) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '-') + @($Miner_Port) + @($_.Threads) | Select-Object) -join '-').json"
            $ThreadsConfigFileName = "$((@("ThreadsConfig") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '-') | Select-Object) -join '-').json"
            $PoolParameters = " --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --userpass=$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass) --keepalive$(if ($Pools.$Algorithm_Norm.Name -eq 'Nicehash') {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"
            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content  = [PSCustomObject]@{
                        "algo"             = $_.Algorithm
                        "api" = [PSCustomObject]@{
                            "port"         = $Miner_Port
                            "access-token" = $null
                            "worker-id"    = $null
                        }
                        "background"       = $false
                        "colors"           = $true
                        "cuda-bfactor"     = 11
                        "cuda-max-threads" = 64
                        "donate-level"     = 1
                        "log-file"         = $null
                        "print-time"       = 5
                        "retries"          = 5
                        "retry-pause"      = 5
                    }
                }
                Commands = ("$Command$CommonCommands$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"}) --config=$ConfigFileName --cuda-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
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
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "XmRig"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            }
        }
    }
}
