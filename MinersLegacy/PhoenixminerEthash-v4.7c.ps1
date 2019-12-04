using module ..\Include.psm1

param(
    [PSCustomObject]$Pools, 
    [PSCustomObject]$Stats, 
    [PSCustomObject]$Config, 
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\PhoenixMiner.exe"
$HashSHA256 = "10C895B3BF06A72FAEB096857200BA5D93A363AF02A8BCF8CB0ADE08900C8E67"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/phoenixminer/PhoenixMiner_4.7c_Windows.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$UnsupportedDriverVersions = @()
$CUDAVersion = ($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA" | Select-Object -Unique).OpenCL.Platform.Version -replace ".*CUDA "
$AMDVersion = ($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD" | Select-Object -Unique).OpenCL.DriverVersion

if ($UnsupportedDriverVersions -contains $AMDVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) does not support the installed AMD driver version $($AMDVersion). Please use a different AMD driver version. "
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "ethash"     ; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = ""          ; } #Ethash
    [PSCustomObject]@{ Algorithm = "ethash"     ; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; Command = ""; Coin = ""          ; } #Ethash/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash-2gb" ; MinMemGB = 2; SecondaryAlgorithm = ""       ; Command = ""; Coin = ""          ; } #Ethash2GB
    [PSCustomObject]@{ Algorithm = "ethash-2gb" ; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; Command = ""; Coin = ""          ; } #Ethash2GB/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash-3gb" ; MinMemGB = 3; SecondaryAlgorithm = ""       ; Command = ""; Coin = ""          ; } #Ethash3GB
    [PSCustomObject]@{ Algorithm = "ethash-3gb" ; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; Command = ""; Coin = ""          ; } #Ethash3GB/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash-4gb" ; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = ""          ; } #Ethash4GB
    [PSCustomObject]@{ Algorithm = "ethash-4gb" ; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; Command = ""; Coin = ""          ; } #Ethash4GB/Blake2s
    [PSCustomObject]@{ Algorithm = "progpow"    ; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin bci"; } #Progpow
    [PSCustomObject]@{ Algorithm = "progpow-2gb"; MinMemGB = 2; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin bci"; } #Progpow2GB
    [PSCustomObject]@{ Algorithm = "progpow-3gb"; MinMemGB = 3; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin bci"; } #Progpow3GB
    [PSCustomObject]@{ Algorithm = "progpow-4gb"; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin bci"; } #Progpow4GB
    [PSCustomObject]@{ Algorithm = "Ubqhash"    ; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin ubq"; } #Ubqhash
    [PSCustomObject]@{ Algorithm = "Ubqhash-2gb"; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin ubq"; } #Ubqhash2GB
    [PSCustomObject]@{ Algorithm = "Ubqhash-3gb"; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin ubq"; } #Ubqhash3GB
    [PSCustomObject]@{ Algorithm = "Ubqhash-4gb"; MinMemGB = 4; SecondaryAlgorithm = ""       ; Command = ""; Coin = " -coin ubq"; } #Ubqhash4GB
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

$SecondaryAlgoIntensities = [PSCustomObject]@{ 
    "blake2s" = @(30, 60, 90, 120)
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

#CommonCommandsAll from config file take precedence
if ($Miner_Config.CommonCommandsAll) { $CommonCommandsAll = $Miner_Config.CommonCommandsAll }
else { $CommonCommandsAll = " -log 0 -wdog 0 -mclock 0 -eres 1 -mi 13 -leaveoc" }

#CommonCommandsNvidia from config file take precedence
if ($Miner_Config.CommonCommandsNvidia) { $CommonCommandsNvidia = $Miner_Config.CommonCommandsNvidia }
else { $CommonCommandsNvidia = " -nvidia -nvdo 1" }

#CommonCommandsAmd from config file take precedence
if ($Miner_Config.CommonCommandsAmd) { $CommonCommmandAmd = $Miner_Config.CommonCommandsAmd }
else { $CommonCommandsAmd = " -amd" }

$DonateCoins = [String[]]("akroma", "ath", "aura", "b2g", "bci", "clo", "dbix", "ella", "egem", "esn", "etc", "etcc", "eth", "etho", "etp", "exp", "gen", "mix", "moac", "music", "nuko", "pgc", "pirl", "qkc", "reosc", "ubq", "vic", "whale", "yoc")

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object { $UnsupportedDriverVersions -notcontains $_.OpenCL.DriverVersion })
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    switch ($_.Vendor) { 
        "AMD" { $CommonCommands = $CommonCommandsAmd + $CommonCommandsAll }
        "NVIDIA" { $CommonCommands = $CommonCommandsNvidia + $CommonCommandsAll }
        Default { $CommonCommands = $CommonCommandsAll }
    }

    $Commands | ForEach-Object { $Algorithm_Norm = @(@(Get-Algorithm ($_.Algorithm -split '-' | Select-Object -First 1) | Select-Object) + @($_.Algorithm -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $Arguments_Primary = ""
        $Arguments_Secondary = ""
        $MinMemGB = $_.MinMemGB
        $TurboKernel = ""

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            if ($_.Coin) { $Coin = $_.Coin }
            elseif ($Pools.$Algorithm_Norm.CurrencySymbol -in $DonateCoins) { $Coin = " -coin $($Pools.$Algorithm_Norm.CurrencySymbol)" }
            else { $Coin = " -coin auto" }

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            if ($null -ne $_.SecondaryAlgoIntensity) { 
                $SecondaryAlgorithm = $_.SecondaryAlgorithm
                $SecondaryAlgorithm_Norm = @(@(Get-Algorithm ($_.SecondaryAlgorithm -split '-' | Select-Object -First 1) | Select-Object) + @($_.SecondaryAlgorithm -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'

                $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) + @("$Algorithm_Norm$SecondaryAlgorithm_Norm") + @($_.SecondaryAlgoIntensity) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week; $SecondaryAlgorithm_Norm = $Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week }

                $Arguments_Secondary += " -dcoin $SecondaryAlgorithm -dpool $(if ($Pools.$SecondaryAlgorithm_Norm.SSL) { "ssl://" })$($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpass $($Pools.$SecondaryAlgorithm_Norm.Pass)$(if($_.SecondaryAlgoIntensity -ge 0){ " -sci $($_.SecondaryAlgoIntensity)" })"
                $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 0.9 / 100; $SecondaryAlgorithm_Norm = 0 / 100 }

                $IntervalMultiplier = 2
                $WarmupTime = 60
            }
            else { 
                $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                $Arguments_Primary += " -gt 0" #Enable auto-tuning

                $WarmupTime = 45
                $Miner_Fees = [PSCustomObject]@{ "$Algorithm_Norm" = 0.65 / 100 }

                #TurboKernels
                if ($Miner_Device.Vendor -eq "AMD" -and ([math]::Round((10 * ($Miner_Device.OpenCL | Measure-Object GlobalMemSize -Minimum).Minimum / 1GB), 0) / 10) -ge (2 * $MinMemGB)) { 
                    #faster AMD "turbo" kernels require twice as much VRAM
                    $TurboKernel = " -clkernel 3"
                }
            }

            if ($null -eq $_.SecondaryAlgoIntensity -or $Pools.$SecondaryAlgorithm_Norm.Host) { 
                [PSCustomObject]@{ 
                    Name               = $Miner_Name
                    DeviceName         = $Miner_Device.Name
                    Path               = $Path
                    HashSHA256         = $HashSHA256
                    Arguments          = ("$Command$CommonCommands$($Coin.ToLower()) -mport -$Miner_Port$(if(($Pools.$Algorithm_Norm.Name -like "NiceHash*" -or $Pools.$Algorithm_Norm.Name -like "MiningPoolHub*") -and $Algorithm_Norm -match '^(ethash(-.+|))$') { " -proto 4" }) -pool $(if ($Pools.$Algorithm_Norm.SSL) { "ssl://" })$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass)$Arguments_Primary$Arguments_Secondary$TurboKernel -gpus $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Slot + 1) }) -join ',')" -replace "\s+", " ").trim()
                    HashRates          = $Miner_HashRates
                    API                = "Claymore"
                    Port               = $Miner_Port
                    URI                = $Uri
                    Fees               = $Miner_Fees
                    IntervalMultiplier = $IntervalMultiplier
                    WarmupTime         = $WarmupTime #seconds
                }
            }
        }
    }
}
