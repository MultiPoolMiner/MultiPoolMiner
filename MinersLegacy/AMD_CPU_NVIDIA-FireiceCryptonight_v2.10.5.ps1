using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\xmr-stak.exe"
$HashSHA256 = "DAA7E84E9F8BE9EECB664A955CB74C64743A7027B1CC068439DA97950C83FCCC"
$Uri = "https://github.com/fireice-uk/xmr-stak/releases/download/2.10.5/xmr-stak-win64-2.10.5.zip"
$ManualUri = "https://github.com/fireice-uk/xmr-stak"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

# Miner requires CUDA 9.0.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.0.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        # Note: For fine tuning directly edit the config files in the miner binary directory
        #       'ThreadsConfig-[Algorithm_Norm]-[Hardware].json' & 'Config-[Algorithm_Norm]-[Hardware]-[Port].json'
        #                             Miner algo name                MinMem        Params       Algorithm_Norm (as returned from Get-Algorithm)
        [PSCustomObject]@{Algorithm = "cryptonight_bittube2";        MinMemGB = 4; Params = ""} #CryptonightHeavyTube
        [PSCustomObject]@{Algorithm = "cryptonight_gpu";             MinMemGB = 1; Params = ""} #CryptonightGpu
        [PSCustomObject]@{Algorithm = "cryptonight_lite";            MinMemGB = 1; Params = ""} #CryptonightLite
        [PSCustomObject]@{Algorithm = "cryptonight_lite_v7";         MinMemGB = 1; Params = ""} #CryptonightLiteV7
        [PSCustomObject]@{Algorithm = "cryptonight_lite_v7_xor";     MinMemGB = 1; Params = ""} #CryptonightLiteIpbc
        [PSCustomObject]@{Algorithm = "cryptonight_haven";           MinMemGB = 4; Params = ""} #CryptonightHeavyHaven
        [PSCustomObject]@{Algorithm = "cryptonight_heavy";           MinMemGB = 4; Params = ""} #CryptonightHeavy
        [PSCustomObject]@{Algorithm = "cryptonight_masari";          MinMemGB = 2; Params = ""} #CryptonightMsr
        [PSCustomObject]@{Algorithm = "cryptonight_r";               MinMemGB = 2; Params = ""} #CryptonightR, new in 2.10.0
        [PSCustomObject]@{Algorithm = "cryptonight_v8_double";       MinMemGB = 4; Params = ""} #CryptonightDouvleV8, new in 2.10.0
        [PSCustomObject]@{Algorithm = "cryptonight_v8_reversewaltz"; MinMemGB = 2; Params = ""} #CryptonightRwzV8, new in 2.10.0
        [PSCustomObject]@{Algorithm = "cryptonight_v7";              MinMemGB = 2; Params = ""} #CryptonightV7
        [PSCustomObject]@{Algorithm = "cryptonight_v7_stellite";     MinMemGB = 2; Params = ""} #CryptonightXtl
        [PSCustomObject]@{Algorithm = "cryptonight_v8";              MinMemGB = 2; Params = ""} #CryptonightV8
     
        # ASIC (09/07/2018)
        #[PSCustomObject]@{Algorithm = "cryptonight";                 MinMemGB = 2; Params = @()} #CryptoNight
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Coins = @("aeon7", "bbscoin", "bittube", "freehaven", "graft", "haven", "intense", "masari", "monero" ,"qrl", "ryo", "stellite", "turtlecoin")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Devices_Platform = @($Devices | Where-Object Vendor -EQ $_.Vendor)
    $Device = @($Devices_Platform | Where-Object Model -EQ $_.Model)
    
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {$_.Type -eq "CPU" -or ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
            $Currency = if ($Coins -icontains $Pools.$Algorithm_Norm.CoinName) {$Pools.$Algorithm_Norm.CoinName} else {$Algorithm}
            
            if ($Miner_Device.Type -eq "CPU") {
                $Platform = "CPU"
                $NoPlatform = " --noAMD --noNVIDIA"
            }
            elseif ($Miner_Device.Vendor -eq "NVIDIA Corporation") {
                $Platform = "NVIDIA"
                $NoPlatform = " --noCPU --noAMD"
            }
            else {
                $Platform = "AMD"
                $NoPlatform = " --noNVIDIA --noCPU"
            }

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }            

            $ConfigFileName = "$((@("Config") + @($Platform) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '_') + @($Miner_Port) | Select-Object) -join '-').txt"
            $MinerThreadsConfigFile = "$((@("ThreadsConfig") + @($Platform) + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '_') | Select-Object) -join '-').txt"
            $PlatformThreadsConfigFile = "$((@("HwConfig") + @($Platform) + @($Algorithm_Norm) + @(($Devices_Platform.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Devices_Platform | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Devices_Platform | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '_') | Select-Object) -join '-').txt"
            $PoolFileName = "$((@("PoolConf") + @($Pools.$Algorithm_Norm.Name) + @($Algorithm_Norm) + @($Pools.$Algorithm_Norm.User) + @($Pools.$Algorithm_Norm.Pass) | Select-Object) -join '-').txt"

            $Parameters = [PSCustomObject]@{
                PoolFile = [PSCustomObject]@{
                    FileName = $PoolFileName
                    Content  = [PSCustomObject]@{
                        pool_list = @([PSCustomObject]@{
                                pool_address    = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                                wallet_address  = "$($Pools.$Algorithm_Norm.User)"
                                pool_password   = "$($Pools.$Algorithm_Norm.Pass)"
                                use_nicehash    = $($Pools.$Algorithm_Norm.Name -eq "NiceHash")
                                use_tls         = $Pools.$Algorithm_Norm.SSL
                                tls_fingerprint = ""
                                pool_weight     = 1
                                rig_id          = "$($Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker)"
                            }
                        )
                        currency = $Currency
                    }
                }
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content  = [PSCustomObject]@{
                        call_timeout    = 10
                        retry_time      = 10
                        giveup_limit    = 0
                        verbose_level   = 99
                        print_motd      = $true
                        h_print_time    = 60
                        aes_override    = $null
                        use_slow_memory = "warn"
                        tls_secure_algo = $true
                        daemon_mode     = $false
                        flush_stdout    = $false
                        output_file     = ""
                        httpd_port      = [Int]$Miner_Port
                        http_login      = ""
                        http_pass       = ""
                        prefer_ipv4     = $true
                    }
                }
                Commands = ("--poolconf $PoolFileName --config $ConfigFileName$NoPlatform --$($Platform.ToLower()) $MinerThreadsConfigFile$(if ($Platform -eq 'NVIDIA') {' --openCLVendor NVIDIA'}) --noUAC --httpd $($Miner_Port)$Parameters$CommonParameters").trim()
                Devices  = @($Miner_Device.Type_Vendor_Index)
                HwDetectCommands = ("--poolconf $PoolFileName --config $ConfigFileName$NoPlatform --$($Platform.ToLower()) $PlatformThreadsConfigFile$(if ($Platform -eq 'NVIDIA') {' --openCLVendor NVIDIA'}) --httpd $($Miner_Port)$Parameters$CommonParameters").trim()
                MinerThreadsConfigFile = $MinerThreadsConfigFile
                Platform = $Platform
                PlatformThreadsConfigFile = $PlatformThreadsConfigFile
                Threads = 1
            }

            if ($Miner_Device.PlatformId) {$Parameters.ConfigFile.Content | Add-Member "platform_index" (($Miner_Device | Select-Object PlatformId -Unique).PlatformId)}

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Parameters
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Fireice"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
                WarmupTime = $(if($Platform-eq "AMD") {120} else {$Config.WarmupTime})
            }
        }
    }
}
