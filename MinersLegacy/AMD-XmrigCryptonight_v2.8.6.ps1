using module ..\Include.psm1

#XmRig AMD / Nvidia requires the explicit use of detailled thread information in the config file
#these values are different for each card model nad algorithm
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
$HashSHA256 = "A4E7ED43E32BED11D5FEFFDC8642E97AF67E4A8310ED777B308108B6B3152CD7"
$Uri = "https://github.com/xmrig/xmrig-amd/releases/download/v2.8.6/xmrig-amd-2.8.6-msvc-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig-amd"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit the config file in the miner binary directory
    #       'Config-[Pool]_[Algorithm_Norm]-[Port]-[User]-[Pass].json'
    [PSCustomObject]@{Algorithm = "cryptonight/0";           MinMemGB = 2; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNight    
    [PSCustomObject]@{Algorithm = "cryptonight/1";           MinMemGB = 2; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight/2";           MinMemGB = 2; Threads = 1; Params = " --opencl-strided-index=2 --opencl-mem-chunk=1"} # CryptoNightV8, new with 2.8.1
    [PSCustomObject]@{Algorithm = "cryptonight/msr";         MinMemGB = 2; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight/rto";         MinMemGB = 2; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightRto
    [PSCustomObject]@{Algorithm = "cryptonight/xao";         MinMemGB = 2; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightXao
    [PSCustomObject]@{Algorithm = "cryptonight/xtl";         MinMemGB = 2; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight-lite/0";      MinMemGB = 1; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight-lite/1";      MinMemGB = 1; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight-lite/2";      MinMemGB = 1; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightLiteV8
    [PSCustomObject]@{Algorithm = "cryptonight-heavy";       MinMemGB = 4; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/tube";  MinMemGB = 4; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/xhv";   MinMemGB = 4; Threads = 1; Params = " --opencl-strided-index=1"} # CryptoNightHeavyHaven
    [PSCustomObject]@{Algorithm = "cryptonight/0";           MinMemGB = 2; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNight    
    [PSCustomObject]@{Algorithm = "cryptonight/1";           MinMemGB = 2; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight/2";           MinMemGB = 2; Threads = 2; Params = " --opencl-strided-index=2 --opencl-mem-chunk=1"} # CryptoNightV8, new with 2.8.1
    [PSCustomObject]@{Algorithm = "cryptonight/msr";         MinMemGB = 2; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight/rto";         MinMemGB = 2; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightRto
    [PSCustomObject]@{Algorithm = "cryptonight/xao";         MinMemGB = 2; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightXao
    [PSCustomObject]@{Algorithm = "cryptonight/xtl";         MinMemGB = 2; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight-lite/0";      MinMemGB = 1; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight-lite/1";      MinMemGB = 1; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight-lite/2";      MinMemGB = 1; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightLiteV8
    [PSCustomObject]@{Algorithm = "cryptonight-heavy";       MinMemGB = 4; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/tube";  MinMemGB = 4; Threads = 2; Params = " --opencl-strided-index=1"} # CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/xhv";   MinMemGB = 4; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightHeavyHaven
    [PSCustomObject]@{Algorithm = "cryptonight/0";           MinMemGB = 2; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNight    
    [PSCustomObject]@{Algorithm = "cryptonight/1";           MinMemGB = 2; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight/2";           MinMemGB = 2; Threads = 3; Params = " --opencl-strided-index=2 --opencl-mem-chunk=1"} # CryptoNightV8, new with 2.8.1
    [PSCustomObject]@{Algorithm = "cryptonight/msr";         MinMemGB = 2; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight/rto";         MinMemGB = 2; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightRto
    [PSCustomObject]@{Algorithm = "cryptonight/xao";         MinMemGB = 2; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightXao
    [PSCustomObject]@{Algorithm = "cryptonight/xtl";         MinMemGB = 2; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight-lite/0";      MinMemGB = 1; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight-lite/1";      MinMemGB = 1; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight-lite/2";      MinMemGB = 1; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightLiteV8
    [PSCustomObject]@{Algorithm = "cryptonight-heavy";       MinMemGB = 4; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/tube";  MinMemGB = 4; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/xhv";   MinMemGB = 4; Threads = 3; Params = " --opencl-strided-index=1"} # CryptoNightHeavyHaven
)
$CommonCommands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | ForEach-Object {

        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $Params = $_.Params
        $Threads = $_.Threads
        $MinMemGB = $_.MinMemGB * $Threads

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @($Threads) | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) + @($Threads) | Select-Object) -join '-'
            }

            #Get commands for active miner devices
            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @($Miner_Device.Model_Norm -Join "_") + @($Miner_Port) + @($Threads) | Select-Object) -join '-').json"
            $ThreadsConfigFileName = "$((@("ThreadsConfig") + @($Algorithm_Norm) + @($Devices.Model_Norm -Join "_") | Select-Object) -join '-').json"
            $PoolParameters = "--url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --userpass=$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass) --keepalive$(if ($Pools.$Algorithm_Norm.Name -eq 'Nicehash') {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"

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
                Commands = ("$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"}) --config=$ConfigFileName --opencl-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')$(Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index)$CommonCommands" -replace "\s+", " ").trim()
                ThreadsConfigFileName = $ThreadsConfigFileName
                HwDetectCommands = "$PoolParameters --config=$ThreadsConfigFileName$Params$CommonCommands"
                Threads = $Threads
                Devices = @($Miner_Device.Type_Vendor_Index)
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
