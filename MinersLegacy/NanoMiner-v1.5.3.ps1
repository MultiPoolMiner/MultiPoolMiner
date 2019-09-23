using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\nanominer.exe"
$HashSHA256 = "7AE792D0BF7CD56A568C3839E6C1B2F8617DF60E77B6031718F6C67DBF4C311E"
$Uri = "https://github.com/nanopool/nanominer/releases/download/v1.5.3/nanominer-windows-1.5.3.zip"
$ManualUri = "https://github.com/nanopool/nanominer/releases"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = $Devices | Where-Object Type -EQ "GPU"

# Miner requires CUDA 10.0.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.0.00"
if ($Devices.Vendor -contains "NVIDIA Corporation" -and $CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    $Devices = $Devices | Where-Object Vendor -NE "NVIDIA Corporation"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Ethash2gb";               AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #Ethash2GB
    [PSCustomObject]@{Algorithm = "Ethash3gb";               AmdMinMemGB = 3; NvidiaMinMemGB = 3; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #Ethash3GB
    [PSCustomObject]@{Algorithm = "Ethash";                  AmdMinMemGB = 4; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #Ethash
    [PSCustomObject]@{Algorithm = "Ubqhash";                 AmdMinMemGB = 4; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #Ubqhash
    [PSCustomObject]@{Algorithm = "CryptoNight";             AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #Cryptonight
    [PSCustomObject]@{Algorithm = "CryptoNightR";            AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #CryptonightR
    [PSCustomObject]@{Algorithm = "CryptoNightV7";           AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #CryptonightV1
    [PSCustomObject]@{Algorithm = "CryptoNightV8";           AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #CryptonightV2
    [PSCustomObject]@{Algorithm = "CryptoNightReverseWaltz"; AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Command = ""} #CryptonightRwz
    [PSCustomObject]@{Algorithm = "Cuckaroo29";              AmdMinMemGB = 6; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 2; Command = ""} #Cuckaroo29
    [PSCustomObject]@{Algorithm = "Cuckarood29";             AmdMinMemGB = 6; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 2; Command = ""} #Cuckarood29, new with 1.5.0
    [PSCustomObject]@{Algorithm = "RandomHash";              AmdMinMemGB = 0; NvidiaMinMemGB = 0; Vendor = @("CPU");           Fee = 2; Command = ""} #RandomHash, CPU only
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$_.Vendor -contains ($Device.Vendor_ShortName | Select-Object -Unique) -and $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = $_.Algorithm -replace "ethash(\dgb)", "Ethash"
        $Fee = $_.Fee
        $MinMemGB = $_."$($Device.Vendor_ShortName | Select-Object -Unique)MinMemGB"

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '-') + @($Algorithm_Norm) + @($Miner_Port) + @($Pools.$Algorithm_Norm.User) + @($Pools.$Algorithm_Norm.Pass)| Select-Object) -join '-').ini"
            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                FileName = $ConfigFileName
                Content  = "
; MultiPoolMiner autogenerated config file (c) MultiPoolMiner.io
checkForUpdates=false
$(if ($Devices.Vendor_ShortName -eq "NVIDIA Corporation") {
    "coreClocks=+0"
    "memClocks=+0"
})
$(if ($Devices.Vendor_Shortname -eq "AMD") {
    "memTweak=0"
})
mport=0
noLog=true
rigName=$($Config.WorkerName)
watchdog=false
webPort=$($Miner_Port)

[$($Algorithm)]
devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Slot)}) -join ',')
pool1=$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)
wallet=$($Pools.$Algorithm_Norm.User)"
                }
                Commands = "$ConfigFileName$Command$CommonCommands"
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
                API        = "NanoMiner"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $Fee / 100}
                WarmupTime = 90 #seconds
            }
        }
    }
}
