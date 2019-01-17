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

# Miner requires CUDA 9.2
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

if ($DriverVersion -lt [System.Version]("10.0.0")) {
    $HashSHA256 = "86C9D69D1335478200536CE1562C9AB9158270836CC7A0B376EB7838C7C44C0A"
    $Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.9.1/xmrig-nvidia-2.9.1-cuda9_2-win64.zip"
}
else {
    $HashSHA256 = "F0100B67CE3265B6C8228DCC54A4C18B45552BD151A56D6C0FA93A6BBFFBC5F6"
    $Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.9.1/xmrig-nvidia-2.9.1-cuda10-win64.zip"
}

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit [Pool]_[Algorithm]-[Port]-[User]-[Pass].json in the miner binary directory
    [PSCustomObject]@{Algorithm = "Cryptonight/0";           MinMemGB = 2; Threads = 1; Params = ""} # Cryptonight    
    [PSCustomObject]@{Algorithm = "Cryptonight/1";           MinMemGB = 2; Threads = 1; Params = ""} # CryptonightV7
    [PSCustomObject]@{Algorithm = "Cryptonight/2";           MinMemGB = 2; Threads = 1; Params = ""} # CryptonightV8, new with 2.8.0rc
    [PSCustomObject]@{Algorithm = "Cryptonight/half";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightHalf, new with 2.9.1
    [PSCustomObject]@{Algorithm = "Cryptonight/msr";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightMsr
    [PSCustomObject]@{Algorithm = "Cryptonight/rto";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightRto
    [PSCustomObject]@{Algorithm = "Cryptonight/xao";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightXao
    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";         MinMemGB = 2; Threads = 1; Params = ""} # CryptonightXtl
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";      MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLite
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";      MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLiteV7
    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";      MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLiteV8
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";       MinMemGB = 2; Threads = 1; Params = ""} # CryptonightHeavy
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube";  MinMemGB = 2; Threads = 1; Params = ""} # CryptonightHeavyTube
    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";   MinMemGB = 2; Threads = 1; Params = ""} # CryptonightHeavyHaven
    [PSCustomObject]@{Algorithm = "Cryptonight/0";           MinMemGB = 2; Threads = 2; Params = ""} # Cryptonight    
#    [PSCustomObject]@{Algorithm = "Cryptonight/1";           MinMemGB = 2; Threads = 2; Params = ""} # CryptonightV7
#    [PSCustomObject]@{Algorithm = "Cryptonight/2";           MinMemGB = 2; Threads = 2; Params = ""} # CryptonightV8, new with 2.8.0rc
#    [PSCustomObject]@{Algorithm = "Cryptonight/half";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightHalf, new with 2.9.1
#    [PSCustomObject]@{Algorithm = "Cryptonight/msr";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightMsr
#    [PSCustomObject]@{Algorithm = "Cryptonight/rto";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightRto
#    [PSCustomObject]@{Algorithm = "Cryptonight/xao";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightXao
#    [PSCustomObject]@{Algorithm = "Cryptonight/xtl";         MinMemGB = 2; Threads = 2; Params = ""} # CryptonightXtl
#    [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";      MinMemGB = 1; Threads = 2; Params = ""} # CryptonightLite
#    [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";      MinMemGB = 1; Threads = 2; Params = ""} # CryptonightLiteV7
#    [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";      MinMemGB = 1; Threads = 2; Params = ""} # CryptonightLiteV8
#    [PSCustomObject]@{Algorithm = "Cryptonight-heavy";       MinMemGB = 2; Threads = 2; Params = ""} # CryptonightHeavy
#    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube";  MinMemGB = 2; Threads = 2; Params = ""} # CryptonightHeavyTube
#    [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";   MinMemGB = 2; Threads = 2; Params = ""} # CryptonightHeavyHaven
)
$CommonCommands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 3      

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
                        "algo"             = $Algorithm
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
                Commands = ("$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"}) --config=$ConfigFileName --cuda-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')$(Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index)$CommonCommands" -replace "\s+", " ").trim()
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
