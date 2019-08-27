using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\MiniZ.exe"
$HashSHA256 = "C06E8D7E1D43F3B43182F03C79BA2DC430F6CDD53C49DA7A0C355D2A21668C9D"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/MiniZ/miniZ_v1.5q2_cuda10_win-x64-1.zip"
$ManualUri = "https://miniz.ch/download"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

# Miner requires CUDA 10.0.00 or higher
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.0.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash965";    MinMemGB = 2.0; Command = " --par=96,5"}
    [PSCustomObject]@{Algorithm = "Equihash1254";   MinMemGB = 3.0; Command = " --par=125,4"}
    [PSCustomObject]@{Algorithm = "Equihash1445";   MinMemGB = 2.0; Command = " --par=144,5"}
    [PSCustomObject]@{Algorithm = "EquihashR15050"; MinMemGB = 2.0; Command = " --par=150,5"}
    [PSCustomObject]@{Algorithm = "EquihashR15053"; MinMemGB = 2.0; Command = " --par=150,5,3"}
    [PSCustomObject]@{Algorithm = "Equihash1927";   MinMemGB = 3.0; Command = " --par=192,7"}
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --latency --show-shares --all-shares --show-pers --shares-detail --smart-pers --oc2"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm ($_.Algorithm -replace ","); $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $MinMemGB = $_.MinMemGB
        $Pers = ""

        if ($Miner_Device = @($Device | Where-Object {$([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("par") -DeviceIDs $Miner_Device.Type_Vendor_Index
            
            Switch ($Algorithm_Norm) {
                "Equihash1445"   {$Pers = Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default "auto"}
                "EquihashR15053" {$Pers = Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName}
                "Equihash1927"   {$Pers = Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default "auto"}
            }
            if ($Pers) {$Pers = " --pers $Pers"} else {$Pers = ""}

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands$Pers --telemetry=0.0.0.0:$($Miner_Port) --server=$(if ($Pools.$Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Algorithm_Norm.Host) --port=$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$NoFee --cuda-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "MiniZ"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
            }
        }
    }
}
