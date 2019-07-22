using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\nanominer.exe"
$HashSHA256 = "33FB865BBC8F8708ADF997AF2438FF7DAD9ED023064DE6F3206D7E92152C1EC7"
$Uri = "https://github.com/nanopool/nanominer/releases/download/v1.5.2/nanominer-windows-1.5.2.zip"
$ManualUri = "https://github.com/nanopool/nanominer/releases"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

# Miner requires CUDA 10.0.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.0.00"
if ($Devices.Vendor -contains "NVIDIA Corporation" -and $CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    $Devices = $Devices | Where-Object Vendor -NE "NVIDIA Corporation"
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "Ethash2gb";               AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #Ethash2GB
        [PSCustomObject]@{Algorithm = "Ethash3gb";               AmdMinMemGB = 3; NvidiaMinMemGB = 3; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #Ethash3GB
        [PSCustomObject]@{Algorithm = "Ethash";                  AmdMinMemGB = 4; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #Ethash
        [PSCustomObject]@{Algorithm = "Ubqhash";                 AmdMinMemGB = 4; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #Ubqhash
        [PSCustomObject]@{Algorithm = "CryptoNightV5";           AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #CryptonightV5
        [PSCustomObject]@{Algorithm = "CryptoNightV6";           AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #CryptonightV6
        [PSCustomObject]@{Algorithm = "CryptoNightV7";           AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #CryptonightV7
        [PSCustomObject]@{Algorithm = "CryptoNightV8";           AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #CryptonightV8
        [PSCustomObject]@{Algorithm = "CryptoNightReverseWaltz"; AmdMinMemGB = 2; NvidiaMinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Fee = 1; Params = ""} #CryptonightRwzV8
        [PSCustomObject]@{Algorithm = "Cuckaroo29";              AmdMinMemGB = 6; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 2; Params = ""} #Cuckaroo29
        [PSCustomObject]@{Algorithm = "Cuckarood29";             AmdMinMemGB = 6; NvidiaMinMemGB = 4; Vendor = @("AMD", "NVIDIA"); Fee = 2; Params = ""} #Cuckarood29, new with 1.5.0
        [PSCustomObject]@{Algorithm = "RandomHash";              AmdMinMemGB = 0; NvidiaMinMemGB = 0; Vendor = @("CPU");           Fee = 2; Params = ""} #RandomHash, CPU only
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$_.Vendor -contains $Device.Vendor_ShortName -and $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = $_.Algorithm -replace "ethash(\dgb)", "Ethash"
        $Fee = $_.Fee
        $MinMemGB = $_."$($Device.Vendor_ShortName)MinMemGB"
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $_.Parameters $Miner_Device.Type_Index
            }
            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '-') + @($Algorithm_Norm) + @($Miner_Port) + @($Pools.$Algorithm_Norm.User) + @($Pools.$Algorithm_Norm.Pass)| Select-Object) -join '-').ini"
            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content  = "
; MPM autogenerated config file
checkForUpdates = false
$(if ($Devices.Vendor_Short -eq "NVIDIA Corporation") {
    "coreClocks = +0"
    "memClocks = +0"
})
$(if ($Devices.Vendor_Short -eq "AMD") {
    "memTweak = 1"
})
mport = 0
noLog = true
rigName = $($Config.WorkerName)
watchdog = false
webPort = $($Miner_Port)

[$($Algorithm)]
devices = $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.PCIBus_Type_Index)}) -join ',')
pool1 = $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)
wallet = $($Pools.$Algorithm_Norm.User)"
                }
                Commands = "$ConfigFileName$Parameters$CommonParameters"
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
                WarmupTime = 60 #seconds
            }
        }
    }
}
