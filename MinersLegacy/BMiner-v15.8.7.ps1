using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\BMiner.exe"
$HashSHA256 = "53FF85689E0A2A1986B23993394B4EA127A3CF822DD2D7CDABA21087C1949F32"
$Uri = "https://www.bminercontent.com/releases/bminer-lite-v15.8.7-6831c33-amd64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=2519271.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) { $Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*" }

$Devices = $Devices | Where-Object Type -EQ "GPU"

# Miner requires CUDA 9.2.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.00"
if ($Devices.Vendor -contains "NVIDIA Corporation" -and $CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    $Devices = $Devices | Where-Object Vendor -NE "NVIDIA Corporation"
}

$Commands = [PSCustomObject[]]@(
    #Single algo mining
    [PSCustomObject]@ { Algorithm = "EquihashR15053"; Protocol = "beamhash2";    SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Command = "" } #EquihashR15053, new in 11.3.0
    [PSCustomObject]@ { Algorithm = "cuckarood29";    Protocol = "cuckaroo29d";  SecondaryAlgorithm = "";          ; MinMemGB = 4; Vendor = @("NVIDIA"); Command = " --fast" } #Cuckarood29, new in 15.7.1
    [PSCustomObject]@ { Algorithm = "cuckatoo31";     Protocol = "cuckatoo31";   SecondaryAlgorithm = "";          ; MinMemGB = 8; Vendor = @("NVIDIA"); Command = "" } #Cuckatoo31, new in 14.2.0, requires GTX 1080Ti or RTX 2080Ti
    [PSCustomObject]@ { Algorithm = "aeternity";      Protocol = "aeternity";    SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = " --fast" } #Aeternity, new in 11.1.0
    #[PSCustomObject]@ { Algorithm = "equihash";       Protocol = "stratum";      SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Equihash, DSTMEquihash-v0.6.2 is 15% faster
    #[PSCustomObject]@ { Algorithm = "equihash1445";   Protocol = "equihash1445"; SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Equihash1445, AMD_NVIDIA-Gminer_v1.52 is faster
    [PSCustomObject]@ { Algorithm = "ethash";         Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 4; Vendor = @("NVIDIA"); Command = "" } #Ethash
    [PSCustomObject]@ { Algorithm = "ethash2gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Ethash2GB
    [PSCustomObject]@ { Algorithm = "ethash3gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 3; Vendor = @("NVIDIA"); Command = "" } #Ethash3GB
    [PSCustomObject]@ { Algorithm = "ethash2gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "blake14r";  ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Ethash2GB & Blake14r dual mining
    [PSCustomObject]@ { Algorithm = "ethash3gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "blake14r";  ; MinMemGB = 3; Vendor = @("NVIDIA"); Command = "" } #Ethash3GB & Blake14r dual mining
    [PSCustomObject]@ { Algorithm = "ethash";         Protocol = "ethstratum";   SecondaryAlgorithm = "blake14r";  ; MinMemGB = 4; Vendor = @("NVIDIA"); Command = "" } #Ethash & Blake14r dual mining
    # [PSCustomObject]@ { Algorithm = "ethash2gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "blake2s";   ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Ethash2GB & Blake2s dual mining; rejected shares
    # [PSCustomObject]@ { Algorithm = "ethash3gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "blake2s";   ; MinMemGB = 3; Vendor = @("NVIDIA"); Command = "" } #Ethash3GB & Blake2s dual mining; rejected shares
    # [PSCustomObject]@ { Algorithm = "ethash";         Protocol = "ethstratum";   SecondaryAlgorithm = "blake2s";   ; MinMemGB = 4; Vendor = @("NVIDIA"); Command = "" } #Ethash & Blake2s dual mining; rejected shares
    [PSCustomObject]@ { Algorithm = "ethash2gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "tensority"; ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Ethash2GB & Bytom dual mining
    [PSCustomObject]@ { Algorithm = "ethash3gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "tensority"; ; MinMemGB = 3; Vendor = @("NVIDIA"); Command = "" } #Ethash3GB & Bytom dual mining
    [PSCustomObject]@ { Algorithm = "ethash";         Protocol = "ethstratum";   SecondaryAlgorithm = "tensority"; ; MinMemGB = 4; Vendor = @("NVIDIA"); Command = "" } #Ethash & Bytom dual mining
    [PSCustomObject]@ { Algorithm = "ethash2gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "vbk";       ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Ethash2GB & Vbk dual mining
    [PSCustomObject]@ { Algorithm = "ethash3gb";      Protocol = "ethstratum";   SecondaryAlgorithm = "vbk";       ; MinMemGB = 3; Vendor = @("NVIDIA"); Command = "" } #Ethash3GB & Vbk dual mining
    [PSCustomObject]@ { Algorithm = "ethash";         Protocol = "ethstratum";   SecondaryAlgorithm = "vbk";       ; MinMemGB = 4; Vendor = @("NVIDIA"); Command = "" } #Ethash & Vbk dual mining
    [PSCustomObject]@ { Algorithm = "tensority";      Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Command = "" } #Bytom
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

$SecondaryAlgoIntensities = [PSCustomObject]@ { 
    "blake14r"  = @(0) # 0 = Auto-Intensity
    "blake2s"   = @(20, 40, 60) # 0 = Auto-Intensity not working with blake2s
    "tensority" = @(0) # 0 = Auto-Intensity
    "vbk"       = @(0) # 0 = Auto-Intensity
}
#Intensities from config file take precedence
$Miner_Config.SecondaryAlgoIntensities.PSObject.Properties.Name | Select-Object | ForEach-Object { 
    $SecondaryAlgoIntensities | Add-Member $_ $Miner_Config.SecondaryAlgoIntensities.$_ -Force
}

$Commands | ForEach-Object { 
    if ($_.SecondaryAlgorithm) { 
        $Command = $_
        $SecondaryAlgoIntensities.$($_.SecondaryAlgorithm) | Select-Object | ForEach-Object { 
            if ($null -ne $Command.SecondaryAlgoIntensity) { 
                $Command = ($Command | ConvertTo-Json | ConvertFrom-Json)
                $Command | Add-Member SecondaryAlgoIntensity ([String] $_) -Force
                $Commands += $Command
            }
            else { $Command | Add-Member SecondaryAlgoIntensity $_ }
        }
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " -watchdog=false" }

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $_.Vendor -contains ($Device.Vendor_ShortName | Select-Object -Unique) -and $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $Arguments_Secondary = ""
        $IntervalMultiplier = 1
        $MinMemGB = $_.MinMemGB
        $Protocol = $_.Protocol
        if ($Pools.$Algorithm_Norm.SSL) { $Protocol = "$($Protocol)+ssl" }
        $Vendor = $_.Vendor
        $WarmupTime = $null

        #Cuckatoo31 on windows 10 requires 3.5 GB extra
        if ($Algorithm -eq "Cuckatoo31" -and ([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) { $MinMemGB += 3.5 }

        if ($Miner_Device = @($Device | Where-Object { $Vendor -contains $_.Vendor_ShortName -and ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            if ($Algorithm_Norm -eq "Equihash1445") { 
                #define -pers for equihash1445
                $AlgoPers = " -pers $(Get-AlgoCoinPers  -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default 'auto')"
            }
            else { $AlgoPers = "" }

            if ($null -ne $_.SecondaryAlgoIntensity) { 
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object { $Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm" }) + @("$Algorithm_Norm$Secondary_Algorithm_Norm") + @($_.SecondaryAlgoIntensity) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@ { $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week }

                $Arguments_Secondary = " -uri2 $($Secondary_Algorithm)$(if ($Pools.$Secondary_Algorithm_Norm.SSL) { '+ssl' })://$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.Pass))@$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port)$(if($_.SecondaryAlgoIntensity -ge 0) { " -dual-intensity $($_.SecondaryAlgoIntensity)" })"
                $Miner_Fees = [PSCustomObject]@ { $Algorithm_Norm = 1.3 / 100; $Secondary_Algorithm_Norm = 0 / 100 } # Fixed at 1.3%, secondary algo no fee

                $IntervalMultiplier = 2
                $WarmupTime = 120
            }
            else { 
                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object { $Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm" }) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@ { $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                $WarmupTime = 120

                if ($Algorithm_Norm -like "Ethash*") { $MinerFeeInPercent = 0.65 } # Ethash fee fixed at 0.65%
                else { $MinerFeeInPercent = 2 } # Other algos fee fixed at 2%

                $Miner_Fees = [PSCustomObject]@ { $Algorithm_Norm = $MinerFeeInPercent / 100 }
            }

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) { $Miner_Config = [PSCustomObject]@ { DisableDevFeeMining = $Config.DisableDevFeeMining } }
            if ($Miner_Config.DisableDevFeeMining) { 
                $NoFee = " -nofee"
                $Miner_Fees = [PSCustomObject]@ { $Algorithm_Norm = 0 / 100 }
                if ($Secondary_Algorithm_Norm) { $Miner_Fees | Add-Member $Secondary_Algorithm_Norm (0 / 100) }
            }
            else { $NoFee = "" }

            if ($null -eq $_.SecondaryAlgoIntensity -or $Pools.$Secondary_Algorithm_Norm.Host) { 
                [PSCustomObject]@ { 
                    Name               = $Miner_Name
                    BaseName           = $Miner_BaseName
                    Version            = $Miner_Version
                    DeviceName         = $Miner_Device.Name
                    Path               = $Path
                    HashSHA256         = $HashSHA256
                    Arguments          = ("$Command$CommonCommands -api 127.0.0.1:$($Miner_Port)$AlgoPers -uri $($Protocol)://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$Arguments_Secondary$NoFee -devices $(if ($Miner_Device.Vendor -EQ "Advanced Micro Devices, Inc.") { "amd:" })$(($Miner_Device | ForEach-Object { '{0:x}' -f $_.Type_Vendor_Index }) -join ',')" -replace "\s+", " ").trim()
                    HashRates          = $Miner_HashRates
                    API                = "Bminer"
                    Port               = $Miner_Port
                    URI                = $URI
                    Fees               = $Miner_Fees
                    IntervalMultiplier = $IntervalMultiplier
                    WarmupTime         = $WarmupTime #seconds
                }
            }
        }
    }
}
