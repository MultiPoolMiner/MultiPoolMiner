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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "CPU")
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        # Note: For fine tuning directly edit [Pool]_[Algorithm]-[Port]-[User]-[Pass].json in the miner binary directory 
        [PSCustomObject]@{Algorithm = "Cryptonight/0";          MinMemGB = 2; Threads = 1; Params = ""} # Cryptonight    
        [PSCustomObject]@{Algorithm = "Cryptonight/1";          MinMemGB = 2; Threads = 1; Params = ""} # CryptonightV7
        [PSCustomObject]@{Algorithm = "Cryptonight/2";          MinMemGB = 2; Threads = 1; Params = ""} # CryptonightV8, new with 2.8.1
        [PSCustomObject]@{Algorithm = "Cryptonight/double";     MinMemGB = 2; Threads = 1; Params = ""} # CryptonightDoubleV8, new with 2.14.1
        [PSCustomObject]@{Algorithm = "Cryptonight/gpu";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightGpu, new with 2.11.0
        [PSCustomObject]@{Algorithm = "Cryptonight/half";       MinMemGB = 2; Threads = 1; Params = ""} # CryptonightHalfV8, new with 2.9.1
        [PSCustomObject]@{Algorithm = "Cryptonight/msr";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightMsr
        [PSCustomObject]@{Algorithm = "Cryptonight/r";          MinMemGB = 2; Threads = 1; Params = ""} # CryptonightR, new with 2.13.1
        [PSCustomObject]@{Algorithm = "Cryptonight/rto";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightRto
        [PSCustomObject]@{Algorithm = "Cryptonight/rwz";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightRwzV8, new with 2.14.1
        [PSCustomObject]@{Algorithm = "Cryptonight/trtl";       MinMemGB = 2; Threads = 1; Params = ""} # CryptonightTrtl, new with 2.10.0
        [PSCustomObject]@{Algorithm = "Cryptonight/xao";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightXao
        [PSCustomObject]@{Algorithm = "Cryptonight/xtl";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightXtl
        [PSCustomObject]@{Algorithm = "Cryptonight/zls";        MinMemGB = 2; Threads = 1; Params = ""} # CryptonightZls, new with 2.14.1
        [PSCustomObject]@{Algorithm = "Cryptonight-lite/0";     MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLite
        [PSCustomObject]@{Algorithm = "Cryptonight-lite/1";     MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLiteV7
        [PSCustomObject]@{Algorithm = "Cryptonight-lite/2";     MinMemGB = 1; Threads = 1; Params = ""} # CryptonightLiteV8
        [PSCustomObject]@{Algorithm = "Cryptonight-heavy";      MinMemGB = 4; Threads = 1; Params = ""} # CryptonightHeavy
        [PSCustomObject]@{Algorithm = "Cryptonight-heavy/tube"; MinMemGB = 4; Threads = 1; Params = ""} # CryptonightHeavyTube
        [PSCustomObject]@{Algorithm = "Cryptonight-heavy/xhv";  MinMemGB = 4; Threads = 1; Params = ""} # CryptonightHeavyHaven
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB * $Threads
        $Parameters = $_.Parameters
        $Threads = $_.Threads


        if ($Miner_Device = @($Device | Where-Object {[math]::Round((Get-CIMInstance -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @($Threads) | Select-Object) -join '-'

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $_.Parameters $Miner_Device.Type_Vendor_Index
            }

            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '_') + @($Miner_Port) + @($Threads) | Select-Object) -join '-').json"
            $ThreadsConfigFileName = "$((@("ThreadsConfig") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '_') | Select-Object) -join '-').json"
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
                Commands = ("$PoolParameters$(if ($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker) {" --rig-id=$($Config.Pools.($Pools.$Algorithm_Norm.Name).Worker)"}) --config=$ConfigFileName$Parameters$CommonParameters" -replace "\s+", " ").trim()
                HwDetectCommands = "$PoolParameters --config=$ThreadsConfigFileName$Parameters$CommonParameters"
                Threads = $Threads * (($Miner_Device.CIM | Measure-Object ThreadCount -Minimum).Minimum -1)
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
