using module ..\Include.psm1

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\xmr-stak.exe"
$HashSHA256 = "871A94EFEA6749251E5C686856F5AAA3B1B2BD91B58F5720FFFE3B92D7227858"
$Uri = "https://github.com/nemosminer/xmr-stak/releases/download/v2.6/xmr-stak-win64-2.6.0.7z" #Use binary compiled by nemos, has 0% dev fee
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
    #                             Miner algo name            MinMem        Params       Algorithm_Norm (from Get-Algorithm)
    [PSCustomObject]@{Algorithm = "cryptonight_bittube2";    MinMemGB = 4; Params = ""} #CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight_lite";        MinMemGB = 1; Params = ""} #CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight_lite_v7";     MinMemGB = 1; Params = ""} #CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight_lite_v7_xor"; MinMemGB = 1; Params = ""} #CryptoNightLiteIpbc
    [PSCustomObject]@{Algorithm = "cryptonight_haven";       MinMemGB = 4; Params = ""} #CryptoNightHeavyHaven
    [PSCustomObject]@{Algorithm = "cryptonight_heavy";       MinMemGB = 4; Params = ""} #CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight_masari";      MinMemGB = 2; Params = ""} #CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight_v7";          MinMemGB = 2; Params = ""} #CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight_v7_stellite"; MinMemGB = 2; Params = ""} #CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight_v8";          MinMemGB = 2; Params = ""} #CryptoNightV8

    # ASIC (09/07/2018)
    #[PSCustomObject]@{Algorithm = "cryptonight";             MinMemGB = 2; Params = @()} #CryptoNight
)
$CommonCommands = ""

$Coins = @("aeon7", "bbscoin", "croat", "edollar", "electroneum", "graft", "haven", "intense", "ipbc", "karbo", "masari", "monero7", "stellite", "sumokoin", "turtlecoin")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm)} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $Params = $_.Params
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
        
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
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
            $ConfigFileName = "$((@("Config") + @($Pools.$Algorithm_Norm.Name) + @($Pools.$Algorithm_Norm.Algorithm) + @($Pools.$Algorithm_Norm.Region) | Select-Object) -join '-').txt"
            $PoolsFileName = "$((@("Pools") + @($Pools.$Algorithm_Norm.Name) + @($Pools.$Algorithm_Norm.Algorithm) + @($Pools.$Algorithm_Norm.Region) | Select-Object) -join '-').txt"
            $PlatformThreadsConfigFile = "$((@("HwConfig") + @($Platform) + @(($Devices | Where-Object Vendor -EQ $Miner_Device.Vendor | Select-Object -ExpandProperty Model_Norm) -Join "_") | Select-Object) -join '-').txt"
            $MinerThreadsConfigFile = "$((@("ThreadsConfig") + @(($Miner_Device | Select-Object -ExpandProperty Model_Norm) -Join "_") + @($Algorithm_Norm) | Select-Object) -join '-').txt"
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
                HwDetectCommands = ("--poolconf $PoolsFileName --config $ConfigFileName$NoPlatform --$($Platform.ToLower()) $PlatformThreadsConfigFile$(if ($Platform -eq 'NVIDIA') {' --openCLVendor NVIDIA'}) --noUAC --httpd $($Miner_Port)$($CommonCommands)").trim()
                Devices  = @($Miner_Device.Type_Vendor_Index)
                Platform = $Platform
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
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 0 / 100}
            }
        }
    }
}
