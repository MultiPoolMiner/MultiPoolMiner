using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\SRBMiner-CN.exe"
$HashSHA256 = "D367515CC70E7D0B3E9153D2AF72AAFDDD5EC8094F5A321E8166F610291DFAB3"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/SRBMiner/SRBMiner-CN-V1-6-9.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3167363.0"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = "40{0:d2}"
                
# Algorithm names are case sensitive!
$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit GpuConf_[HW]-[Threads]-[Algorithm]-[Port]-[User]-[Pass].json in the miner binary directory 
    [PSCustomObject]@{Algorithm = "alloy";      Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightXao 1 thread
    [PSCustomObject]@{Algorithm = "artocash";   Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightRto 1 thread
    [PSCustomObject]@{Algorithm = "b2n";        Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightB2N 1 thread
    [PSCustomObject]@{Algorithm = "bittubev2";  Threads = 1; MinMemGb = 4; Params = ""; Intensity = @()} # CryptonightHeavyTube 1 thread
    [PSCustomObject]@{Algorithm = "fast";       Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightFast 1 thread
    [PSCustomObject]@{Algorithm = "lite";       Threads = 1; MinMemGb = 1; Params = ""; Intensity = @()} # CryptonightLite 1 thread
    [PSCustomObject]@{Algorithm = "liteV7";     Threads = 1; MinMemGb = 1; Params = ""; Intensity = @()} # CryptonightLiteV7 1 thread
    [PSCustomObject]@{Algorithm = "haven";      Threads = 1; MinMemGb = 4; Params = ""; Intensity = @()} # CryptonightHeavyHaven 1 thread
    [PSCustomObject]@{Algorithm = "heavy";      Threads = 1; MinMemGb = 4; Params = ""; Intensity = @()} # CryptonightHeavy 1 thread
    [PSCustomObject]@{Algorithm = "marketcash"; Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightMarketCash 1 thread
    [PSCustomObject]@{Algorithm = "normalv7";   Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightV7 1 thread
    [PSCustomObject]@{Algorithm = "normalv8";   Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightV8 1 thread, new in 1.6.8
    [PSCustomObject]@{Algorithm = "stellitev4"; Threads = 1; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightXtl 1 thread
    [PSCustomObject]@{Algorithm = "alloy";      Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightXao 2 threads
    [PSCustomObject]@{Algorithm = "artocash";   Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightRto 2 threads
    [PSCustomObject]@{Algorithm = "b2n";        Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightB2N 2 threads
    [PSCustomObject]@{Algorithm = "bittubev2";  Threads = 2; MinMemGb = 4; Params = ""; Intensity = @()} # CryptonightHeavyTube 2 threads
    [PSCustomObject]@{Algorithm = "fast";       Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightFast 2 threads
    [PSCustomObject]@{Algorithm = "lite";       Threads = 2; MinMemGb = 1; Params = ""; Intensity = @()} # CryptonightLite 2 threads
    [PSCustomObject]@{Algorithm = "liteV7";     Threads = 2; MinMemGb = 1; Params = ""; Intensity = @()} # CryptonightLiteV7 2 threads
    [PSCustomObject]@{Algorithm = "haven";      Threads = 2; MinMemGb = 4; Params = ""; Intensity = @()} # CryptonightHeavyHaven 2 threads
    [PSCustomObject]@{Algorithm = "heavy";      Threads = 2; MinMemGb = 4; Params = ""; Intensity = @()} # CryptonightHeavy 2 threads
    [PSCustomObject]@{Algorithm = "marketcash"; Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightMarketCash 2 threads
    [PSCustomObject]@{Algorithm = "normalv7";   Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightV7 2 threads
    [PSCustomObject]@{Algorithm = "normalv8";   Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightV8 2 threads, new in 1.6.8
    [PSCustomObject]@{Algorithm = "stellitev4"; Threads = 2; MinMemGb = 2; Params = ""; Intensity = @()} # CryptonightXtl 2 threads

    # Asic only (2018/07/12)
    #[PSCustomObject]@{Algorithm = "normal";     Threads = 1; MinMemGb = 2} # Cryptonight 1 thread
)
$CommonCommands = ""

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc."

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm "Cryptonight$($Algorithm)"
        $Threads = $_.Threads
        $MinMem = $_.MinMemGb * 1GB
        $Params = $_.Params
        $Intensity = $_.Intensity

        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMem)})

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_;"$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @($Threads) | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            }

            #Get commands for active miner devices
            $Params = Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index

            $ConfigFileName = "GpuConf_$($Pools.$Algorithm_Norm.Name)-$(($Devices | Where-Object {$_.Type -eq $Miner_Device.Type -and $_.Vendor -eq $Miner_Device.Vendor}).Model_Norm -join '_')-$Algorithm_Norm-$Threads-$Miner_Port-$($Pools.$Algorithm_Norm.User)-$($Pools.$Algorithm_Norm.Pass).json"
            $PoolFileName = "PoolConf_$($Pools.$Algorithm_Norm.Name)-$($Algorithm_Norm).json"

            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content  = [PSCustomObject]@{
                        cryptonight_type = $Algorithm
                        intensity        = 0
                        double_threads   = $false
                        gpu_conf         = @($Miner_Device.Type_PlatformId_Index | Foreach-Object {
                            [PSCustomObject]@{
                                "id"        = $_  
                                "intensity" = $(if ($Intensity | Select-Object -Index $_ -ErrorAction SilentlyContinue) {$Intensity | Select-Object -Index $_} else {0})
                                "threads"   = [Int]$Threads
                                "platform"  = "OpenCL"
                                #"worksize"  = [Int]8
                            }
                        })
                    }
                }
                PoolFile = [PSCustomObject]@{
                    FileName = $PoolFileName
                    Content  = [PSCustomObject]@{
                        pools = @([PSCustomObject]@{
                            pool = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                            wallet = "$($Pools.$Algorithm_Norm.User)"
                            password = "$($Pools.$Algorithm_Norm.Pass)"
                            pool_use_tls = $($Pools.$Algorithm_Norm.SSL)
                            nicehash = $($Pools.$Algorithm_Norm.Name -eq 'NiceHash')
                        })
                    }
                }
                Commands = ("--config $ConfigFileName --pools $PoolFileName --apienable --apiport $Miner_Port --apirigname $($Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker)$Params$CommonCommands" -replace "\s+", " ").trim()
            }
                        
            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Arguments
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "SRBMiner"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 0.85 / 100}
            }
        }
    }
}
