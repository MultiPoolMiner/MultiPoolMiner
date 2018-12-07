using module ..\Include.psm1

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\xmr-stak.exe"
$HashSHA256 = "7980E668BC1B47B0895703839339A018DEFBF30DF049C367D7192777FACAC0B0"
$Uri = "https://github.com/fireice-uk/xmr-stak/releases/download/2.7.0/xmr-stak-win64-2.7.0.zip"
$ManualUri = "https://github.com/fireice-uk/xmr-stak"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = "40{0:d2}"

# Miner requires CUDA 9.0.00 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.0.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit the config files in the miner binary directory
    #       'ThreadsConfig-[Algorithm_Norm]-[Hardware].json' & 'Config-[Algorithm_Norm]-[Hardware]-[Port]-[Threads].json'
    #                             Miner algo name            MinMem        Params       Algorithm_Norm (from Get-Algorithm)
    [PSCustomObject]@{Algorithm = "cryptonight_bittube2";    MinMemGB = 4; Threads = 1; Params = ""} #CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight_lite";        MinMemGB = 1; Threads = 1; Params = ""} #CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight_lite_v7";     MinMemGB = 1; Threads = 1; Params = ""} #CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight_lite_v7_xor"; MinMemGB = 1; Threads = 1; Params = ""} #CryptoNightLiteIpbc
    [PSCustomObject]@{Algorithm = "cryptonight_haven";       MinMemGB = 4; Threads = 1; Params = ""} #CryptoNightHeavyHaven
    [PSCustomObject]@{Algorithm = "cryptonight_heavy";       MinMemGB = 4; Threads = 1; Params = ""} #CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight_masari";      MinMemGB = 2; Threads = 1; Params = ""} #CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight_v7";          MinMemGB = 2; Threads = 1; Params = ""} #CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight_v7_stellite"; MinMemGB = 2; Threads = 1; Params = ""} #CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight_v8";          MinMemGB = 2; Threads = 1; Params = ""} #CryptoNightV8
    [PSCustomObject]@{Algorithm = "cryptonight_bittube2";    MinMemGB = 4; Threads = 2; Params = ""} #CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight_lite";        MinMemGB = 1; Threads = 2; Params = ""} #CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight_lite_v7";     MinMemGB = 1; Threads = 2; Params = ""} #CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight_lite_v7_xor"; MinMemGB = 1; Threads = 2; Params = ""} #CryptoNightLiteIpbc
    [PSCustomObject]@{Algorithm = "cryptonight_haven";       MinMemGB = 4; Threads = 2; Params = ""} #CryptoNightHeavyHaven
    [PSCustomObject]@{Algorithm = "cryptonight_heavy";       MinMemGB = 4; Threads = 2; Params = ""} #CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight_masari";      MinMemGB = 2; Threads = 2; Params = ""} #CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight_v7";          MinMemGB = 2; Threads = 2; Params = ""} #CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight_v7_stellite"; MinMemGB = 2; Threads = 2; Params = ""} #CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight_v8";          MinMemGB = 2; Threads = 2; Params = ""} #CryptoNightV8

    # ASIC (09/07/2018)
    #[PSCustomObject]@{Algorithm = "cryptonight";             MinMemGB = 2; Threads = 1; Params = @()} #CryptoNight
)
$CommonCommands = ""

$Coins = @("aeon7", "bbscoin", "bittube", "freehaven", "graft", "haven", "intense", "masari", "monero" ,"qrl", "ryo", "stellite", "turtlecoin")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm)} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $Params = $_.Params
        $MinMemGB = $_.MinMemGB
        $Threads = $_.Threads

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
        
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @($Threads) | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) + @($Threads) | Select-Object) -join '-'
            }

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
            
            #Get commands for active miner devices
            $Params = Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index
            $ConfigFileName = "$((@("Config") + @($Platform) + @($Pools.$Algorithm_Norm.Algorithm) + @($Miner_Device.Model_Norm -Join "_") + @($Miner_Port) | Select-Object) -join '-').txt"
            $PoolsFileName = "$((@("Pools") + @($Pools.$Algorithm_Norm.Name) + @($Pools.$Algorithm_Norm.Algorithm) | Select-Object) -join '-').txt"
            $PlatformThreadsConfigFile = "$((@("HwConfig") + @($Platform) + @($Algorithm_Norm) + @(($Devices | Where-Object Vendor -EQ $Miner_Device.Vendor | Select-Object -ExpandProperty Model_Norm) -Join "_") | Select-Object) -join '-').json"
            $MinerThreadsConfigFile = "$((@("ThreadsConfig") + @($Platform) + @($Algorithm_Norm) + @(($Miner_Device | Select-Object -ExpandProperty Model_Norm) -Join "_") + @($Threads) | Select-Object) -join '-').txt"
            $Parameters = [PSCustomObject]@{
                PoolsFile = [PSCustomObject]@{
                    FileName = $PoolsFileName
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
                        verbose_level   = 3
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
                MinerThreadsConfigFile = $MinerThreadsConfigFile
                PlatformThreadsConfigFile = $PlatformThreadsConfigFile
                Commands = ("--poolconf $PoolsFileName --config $ConfigFileName$NoPlatform --$($Platform.ToLower()) $MinerThreadsConfigFile$(if ($Platform -eq 'NVIDIA') {' --openCLVendor NVIDIA'}) --noUAC --httpd $($Miner_Port)$($CommonCommands)").trim()
                HwDetectCommands = ("--poolconf $PoolsFileName --config $ConfigFileName$NoPlatform --$($Platform.ToLower()) $PlatformThreadsConfigFile$(if ($Platform -eq 'NVIDIA') {' --openCLVendor NVIDIA'}) --httpd $($Miner_Port)$($CommonCommands)").trim()
                Devices  = @($Miner_Device.Type_Vendor_Index)
                Platform = $Platform
                Threads = $Threads
            }

            if ($Miner_Device.PlatformId) {$Parameters.ConfigFile.Content | Add-Member "platform_index" (($Miner_Device | Select-Object PlatformId -Unique).PlatformId)}

            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Parameters
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Fireice"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
            }
        }
    }
}
