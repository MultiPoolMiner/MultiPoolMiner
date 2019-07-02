using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\nanominer.exe"
$HashSHA256 = "1EE4A32B8AB65010D26566B82E5768086CED70D78C907C0F37A103102CCC348B"
$Uri = "https://github.com/nanopool/nanominer/releases/download/v1.3.4/nanominer-windows-1.3.4.zip"
$ManualUri = "https://github.com/nanopool/nanominer/releases"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU")

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
        [PSCustomObject]@{Algorithm = "Ethash2gb";               MinMemGB = 2; Fee = 1; Params = ""} #Ethash2GB
        [PSCustomObject]@{Algorithm = "Ethash3gb";               MinMemGB = 3; Fee = 1; Params = ""} #Ethash3GB
        [PSCustomObject]@{Algorithm = "Ethash";                  MinMemGB = 4; Fee = 1; Params = ""} #Ethash
        [PSCustomObject]@{Algorithm = "Ubqhash";                 MinMemGB = 4; Fee = 1; Params = ""} #Ubqhash
        [PSCustomObject]@{Algorithm = "CryptoNightV5";           MinMemGB = 2; Fee = 1; Params = ""} #CryptonightV5
        [PSCustomObject]@{Algorithm = "CryptoNightV6";           MinMemGB = 2; Fee = 1; Params = ""} #CryptonightV6
        [PSCustomObject]@{Algorithm = "CryptoNightV7";           MinMemGB = 2; Fee = 1; Params = ""} #CryptonightV7
        [PSCustomObject]@{Algorithm = "CryptoNightV8";           MinMemGB = 2; Fee = 1; Params = ""} #CryptonightV8
        [PSCustomObject]@{Algorithm = "CryptoNightReverseWaltz"; MinMemGB = 2; Fee = 1; Params = ""} #CryptonightRwzV8
        [PSCustomObject]@{Algorithm = "Cuckaroo29";              MinMemGB = 4; Fee = 2; Params = ""} #Cuckaroo29
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = $_.Algorithm -replace "ethash(\dgb)", "Ethash"
        $Fee = $_.Fee
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

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
            $ConfigFileName = "$((@("Config") + @($Algorithm_Norm) + @(($Miner_Device.Model_Norm | Sort-Object -unique | Sort-Object Name | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm($(($Miner_Device | Sort-Object Name | Where-Object Model_Norm -eq $Model_Norm).Name -join ';'))"} | Select-Object) -join '_') + @($Algorithm_Norm) + @($Miner_Port) + @($Pools.$Algorithm_Norm.User) + @($Pools.$Algorithm_Norm.Pass)| Select-Object) -join '-').ini"
            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content  = "
; MPM autogenerated config file
checkForUpdates = false
$(if ($Devices.Vendor -contains "NVIDIA Corporation") {"coreClocks = +0"})
$(if ($Devices.Vendor -contains "NVIDIA Corporation") {"memClocks = +0"})
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

            if ($Device.Vendor -notcontains "NVIDIA Corporation" -or $Algorithm -ne "Cuckaroo29"<#Temp fix, 1.3.2 does not support Cuckaroo29 on NVidia#>) {
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
                    WarmupTime = 60
                }
            }
        }
    }
}
