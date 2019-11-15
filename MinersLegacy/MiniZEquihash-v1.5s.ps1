using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\MiniZ.exe"
$HashSHA256 = "733963787DD61894DB05297232CB046DB5C3247B601262CD3C26A31DAC25F54A"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/MiniZ/miniZ_v1.5s_cuda10_win-x64.zip"
$ManualUri = "https://miniz.ch/download"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA"

# Miner requires CUDA 10.0.00 or higher
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.0.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject[]]@(
#    [PSCustomObject]@{ Algorithm = "Equihash965";    MinMemGB = 2.0; Command = " --par=96,5" } # Gminer-v1.66 is faster
    [PSCustomObject]@{ Algorithm = "Equihash1254";   MinMemGB = 3.0; Command = " --par=125,4" }
#    [PSCustomObject]@{ Algorithm = "Equihash1445";   MinMemGB = 2.0; Command = " --par=144,5" } # Gminer-v1.66 is faster
#    [PSCustomObject]@{ Algorithm = "EquihashR15050"; MinMemGB = 2.0; Command = " --par=150,5" } #Bad shares
    [PSCustomObject]@{ Algorithm = "EquihashR15053"; MinMemGB = 2.0; Command = " --par=150,5,3" }
#    [PSCustomObject]@{ Algorithm = "Equihash1927";   MinMemGB = 3.0; Command = " --par=192,7" } # Gminer-v1.66 is faster
    [PSCustomObject]@{ Algorithm = "Equihash2109";   MinMemGB = 1.0; Command = " --par=210,9" }
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " --latency --show-shares --all-shares --show-pers --shares-detail --smart-pers --oc2 --pci-order" }

$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm ($_.Algorithm -replace ","); $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB
        $Pers = ""

        if ($Miner_Device = @($Device | Where-Object { $([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("par") -DeviceIDs $Miner_Device.Type_Vendor_Index
            
            Switch ($Algorithm_Norm) { 
                "Equihash1445"   { $Pers = Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default "auto" }
                "EquihashR15053" { $Pers = Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName }
                "Equihash1927"   { $Pers = Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default "auto" }
            }
            if ($Pers) { $Pers = " --pers $Pers" } else { $Pers = "" }

            [PSCustomObject]@{ 
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands$Pers --telemetry=0.0.0.0:$($Miner_Port) --server=$(if ($Pools.$Algorithm_Norm.SSL) { "ssl://" })$($Pools.$Algorithm_Norm.Host) --port=$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$NoFee --cuda-devices=$(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ' ')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                API        = "MiniZ"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{ $Algorithm_Norm = 2 / 100 }
            }
        }
    }
}
