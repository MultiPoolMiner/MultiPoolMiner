using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\xmrig.exe"
$HashSHA256 = "1AAB1D5E9605F10CC87E5811BF165ED812C47395C41676ECE2AC479BAF6B11F9"
$Uri = "https://github.com/xmrig/xmrig/releases/download/v2.14.4/xmrig-2.14.4-gcc-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit [Pool]_[Algorithm]-[Port]-[User]-[Pass].json in the miner binary directory 
    [PSCustomObject]@{ Algorithm = "Cryptonight/0";          MinMemGB = 2; Threads = 1; Command = "" } # Cryptonight    
    [PSCustomObject]@{ Algorithm = "Cryptonight/1";          MinMemGB = 2; Threads = 1; Command = "" } # CryptonightV7
    [PSCustomObject]@{ Algorithm = "Cryptonight/2";          MinMemGB = 2; Threads = 1; Command = "" } # CryptonightV8, new with 2.8.1
    [PSCustomObject]@{ Algorithm = "Cryptonight/double";     MinMemGB = 2; Threads = 1; Command = "" } # CryptonightDoubleV8, new with 2.14.1
    [PSCustomObject]@{ Algorithm = "Cryptonight/gpu";        MinMemGB = 2; Threads = 1; Command = "" } # CryptonightGpu, new with 2.11.0
    [PSCustomObject]@{ Algorithm = "Cryptonight/half";       MinMemGB = 2; Threads = 1; Command = "" } # CryptonightHalfV8, new with 2.9.1
    [PSCustomObject]@{ Algorithm = "Cryptonight/msr";        MinMemGB = 2; Threads = 1; Command = "" } # CryptonightMsr
    [PSCustomObject]@{ Algorithm = "Cryptonight/r";          MinMemGB = 2; Threads = 1; Command = "" } # CryptonightR, new with 2.13.1
    [PSCustomObject]@{ Algorithm = "Cryptonight/rto";        MinMemGB = 2; Threads = 1; Command = "" } # CryptonightRto
    [PSCustomObject]@{ Algorithm = "Cryptonight/rwz";        MinMemGB = 2; Threads = 1; Command = "" } # CryptonightRwzV8, new with 2.14.1
    [PSCustomObject]@{ Algorithm = "Cryptonight/trtl";       MinMemGB = 2; Threads = 1; Command = "" } # CryptonightTrtl, new with 2.10.0
    [PSCustomObject]@{ Algorithm = "Cryptonight/xao";        MinMemGB = 2; Threads = 1; Command = "" } # CryptonightXao
    [PSCustomObject]@{ Algorithm = "Cryptonight/xtl";        MinMemGB = 2; Threads = 1; Command = "" } # CryptonightXtl
    [PSCustomObject]@{ Algorithm = "Cryptonight/zls";        MinMemGB = 2; Threads = 1; Command = "" } # CryptonightZls, new with 2.14.1
    [PSCustomObject]@{ Algorithm = "Cryptonight-lite/0";     MinMemGB = 1; Threads = 1; Command = "" } # CryptonightLite
    [PSCustomObject]@{ Algorithm = "Cryptonight-lite/1";     MinMemGB = 1; Threads = 1; Command = "" } # CryptonightLiteV7
    [PSCustomObject]@{ Algorithm = "Cryptonight-lite/2";     MinMemGB = 1; Threads = 1; Command = "" } # CryptonightLiteV8
    [PSCustomObject]@{ Algorithm = "Cryptonight-heavy";      MinMemGB = 4; Threads = 1; Command = "" } # CryptonightHeavy
    [PSCustomObject]@{ Algorithm = "Cryptonight-heavy/tube"; MinMemGB = 4; Threads = 1; Command = "" } # CryptonightHeavyTube
    [PSCustomObject]@{ Algorithm = "Cryptonight-heavy/xhv";  MinMemGB = 4; Threads = 1; Command = "" } # CryptonightHeavyHaven
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices = @($Devices | Where-Object Type -EQ "CPU")
$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB * $_.Threads

        if ($Miner_Device = @($Device | Where-Object { [math]::Round((Get-CIMInstance -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @(($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) -join '-') + @($_.Threads) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model | Sort-Object -unique | Sort-Object Name | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model($(($Miner_Device | Sort-Object Name | Where-Object Model -eq $Model).Name -join ';'))" } | Select-Object) -join '-') + @($Miner_Port) + @($_.Threads) | Select-Object) -join '-').json"
            $ThreadsConfigFileName = "$((@("ThreadsConfig") + @($Algorithm_Norm) + @(($Miner_Device.Model | Sort-Object -unique | Sort-Object Name | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model($(($Miner_Device | Sort-Object Name | Where-Object Model -eq $Model).Name -join ';'))" } | Select-Object) -join '-') | Select-Object) -join '-').json"
            $PoolParameters = " --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --userpass=$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass) --keepalive$(if ($Pools.$Algorithm_Norm.Name -eq 'Nicehash') { " --nicehash" })$(if ($Pools.$Algorithm_Norm.SSL) { " --tls" })"

            $Arguments = [PSCustomObject]@{ 
                ConfigFile = [PSCustomObject]@{ 
                    FileName = $ConfigFileName
                    Content = [PSCustomObject]@{ 
                        "algo"         = $_.Algorithm
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
                Commands = ("$Command$CommonCommands$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) { " --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)" }) --config=$ConfigFileName" -replace "\s+", " ").trim()
                HwDetectCommands = "$Command$CommonCommands$PoolParameters --config=$ThreadsConfigFileName"
                Threads = $_.Threads * (($Miner_Device.CIM | Measure-Object ThreadCount -Minimum).Minimum -1)
                ThreadsConfigFileName = $ThreadsConfigFileName
            }

            [PSCustomObject]@{ 
                Name       = $Miner_Name
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
