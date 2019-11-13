using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\SRBMiner-CN.exe"
$HashSHA256 = "41F6E563E96A1D2E8AF3B2C6351B25CE0D05E9976A88B29FE3291BBB98424C4D"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/SRBMiner/SRBMiner-CN-V1-9-3.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3167363.0"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config
               
# Algorithm names are case sensitive!
$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit GpuConf_[HW]-[Algorithm]-[User]-[Pass].json in the miner binary directory 
    [PSCustomObject]@{ Algorithm = "alloy";       MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightXao
    [PSCustomObject]@{ Algorithm = "artocash";    MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightRto
    [PSCustomObject]@{ Algorithm = "b2n";         MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightB2N
    [PSCustomObject]@{ Algorithm = "bittubev2";   MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightHeavyTube 
    [PSCustomObject]@{ Algorithm = "conceal";     MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightConceal, new in 1.7.9
    [PSCustomObject]@{ Algorithm = "fast2";       MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightFast2
    [PSCustomObject]@{ Algorithm = "gpu";         MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightRwzV8
    [PSCustomObject]@{ Algorithm = "graft";       MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightV2
    [PSCustomObject]@{ Algorithm = "haven";       MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightHeavyHaven
    [PSCustomObject]@{ Algorithm = "hospital";    MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightV1
    [PSCustomObject]@{ Algorithm = "hycon";       MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightV1, new in 1.7.3
    [PSCustomObject]@{ Algorithm = "litev7";      MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightLiteV7
    [PSCustomObject]@{ Algorithm = "marketcash";  MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightMarketCash
    [PSCustomObject]@{ Algorithm = "mox";         MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightRed
    [PSCustomObject]@{ Algorithm = "normalv4";    MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # Cryptonight
    [PSCustomObject]@{ Algorithm = "normalv7";    MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightV1
    [PSCustomObject]@{ Algorithm = "normalv8";    MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightV2, new in 1.6.8
    [PSCustomObject]@{ Algorithm = "stellitev8";  MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightHalf, new in 1.7.3
    [PSCustomObject]@{ Algorithm = "turtle";      MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightTurtle, new in 1.7.4
    [PSCustomObject]@{ Algorithm = "upx2";        MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightUpx2, new in 1.8.6
    [PSCustomObject]@{ Algorithm = "xcash";       MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightDouble???, new in 1.7.9
    [PSCustomObject]@{ Algorithm = "zelerius";    MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightZls, new in 1.7.9
    # Obsolete, but still supported (20170711)
    #[PSCustomObject]@{ Algorithm = "normal";      MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # Cryptonight
    #[PSCustomObject]@{ Algorithm = "dark";        MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightHeavyTube
    #[PSCustomObject]@{ Algorithm = "fast";        MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightFast
    #[PSCustomObject]@{ Algorithm = "festival";    MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightFestival
    #[PSCustomObject]@{ Algorithm = "heavy";       MinMemGb = 2; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightHeavy
    #[PSCustomObject]@{ Algorithm = "italo";       MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightItalo
    #[PSCustomObject]@{ Algorithm = "lite";        MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightLite
    #[PSCustomObject]@{ Algorithm = "normalv4_64"; MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightV4_64
    #[PSCustomObject]@{ Algorithm = "stellitev4";  MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # CryptonightLite
    #[PSCustomObject]@{ Algorithm = "upx";         MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # Cryptonight???, new in 1.7.3
    #[PSCustomObject]@{ Algorithm = "wownero";     MinMemGb = 1; Command = ""; Intensity = @(); DoubleThreads = $true } # Cryptonight???, new in 1.7.9
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD"
$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm ("cryptonight$($_.Algorithm)"); $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $Algorithm = $_.Algorithm
        $DoubleThreads = $_.DoubleThreads
        $Intensity = $_.Intensity
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            $ConfigFileName = "$((@("GpuConf") + @(($Miner_Device.Model | Sort-Object -unique | Sort-Object Name | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model($(($Miner_Device | Sort-Object Name | Where-Object Model -eq $Model).Name -join ';'))" } | Select-Object) -join '-') + @($Algorithm_Norm) + @($Pools.$Algorithm_Norm.User) + @($Pools.$Algorithm_Norm.Pass) | Select-Object) -join '-').txt"
            $PoolFileName = "$((@("PoolConf") + @($Pools.$Algorithm_Norm.Name) + @($Algorithm_Norm) + @($Pools.$Algorithm_Norm.User) + @($Pools.$Algorithm_Norm.Pass) | Select-Object) -join '-').txt"
            $Arguments = [PSCustomObject]@{ 
                ConfigFile = [PSCustomObject]@{ 
                    FileName = $ConfigFileName
                    Content  = [PSCustomObject]@{ 
                        cryptonight_type = $Algorithm
                        double_threads = $DoubleThreads
                        gpu_conf = @($Miner_Device.Vendor_Slot | ForEach-Object { 
                            [PSCustomObject]@{ 
                                "id"        = $_  
                                "intensity" = $(if ($Intensity | Select-Object -Index $_ -ErrorAction SilentlyContinue) { $Intensity | Select-Object -Index $_ } else { 0 })
                                "platform"  = "OpenCL"
                                #"threads"   = [Int]1
                                #"worksize"  = [Int]8
                            }
                        })
                        intensity = 0
                        min_rig_speed = $(if($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week) { [Int]($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week * 0.9) } else { 0 })
                        min_rig_speed_duration = 60 
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
                Commands = ("$Command$CommonCommands --config $ConfigFileName --pools $PoolFileName --apienable --apiport $Miner_Port$(if($Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker) { " --apirigname $($Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker)" })" -replace "\s+", " ").trim()
            }
                        
            [PSCustomObject]@{ 
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Arguments
                HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                API        = "SRBMiner"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{ $Algorithm_Norm = 0.85 / 100 }
                WarmupTime = 45 #seconds
            }
        }
    }
}
