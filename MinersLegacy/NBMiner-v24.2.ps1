using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\nbminer.exe"
$HashSHA256 = ""
$Uri = "https://github.com/NebuTech/NBMiner/releases/download/v24.2/NBMiner_24.2_Win.zip"
$ManualUri = "https://github.com/gangnamtestnet/progminer/releases"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 9.1.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.1.00"
if ($Devices.Vendor -contains "NVIDIA Corporation" -and $CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    $Devices = $Devices | Where-Object Vendor -NE "NVIDIA Corporation"
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "tensority";           MinMemGB = 1; MinMemGBWin10 = 1;  SecondaryIntensity = 0;  Fee = 2;    Params = ""} #Tensority (BTM)
# ClaymoreDual & Phoenix are approx 10% faster           [PSCustomObject]@{Algorithm = "ethash";               MinMemGB = 4; MinMemGBWin10 = 4; SecondaryIntensity = 0;  Fee = 0.65; Params = ""} #Ethash
# ClaymoreDual & Phoenix are approx 10% faster           [PSCustomObject]@{Algorithm = "ethash2gb";            MinMemGB = 2; MinMemGBWin10 = 2; SecondaryIntensity = 0;  Fee = 0.65; Params = ""} #Ethash2GB
# ClaymoreDual & Phoenix are approx 10% faster           [PSCustomObject]@{Algorithm = "ethash3gb";            MinMemGB = 3; MinMemGBWin10 = 3; SecondaryIntensity = 0;  Fee = 0.65; Params = ""} #Ethash3GB
        [PSCustomObject]@{Algorithm = "tensority_ethash";    MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 2;    Params = ""} #Tensority (BTM) & Ethash
        [PSCustomObject]@{Algorithm = "tensority_ethash2gb"; MinMemGB = 3; MinMemGBWin10 = 2;  SecondaryIntensity = 17; Fee = 2;    Params = ""} #Tensority (BTM) & Ethash2GB
        [PSCustomObject]@{Algorithm = "tensority_ethash3gb"; MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 17; Fee = 2;    Params = ""} #Tensority (BTM) & Ethash3GB
        [PSCustomObject]@{Algorithm = "cuckarood";           MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Params = ""} #Cuckarood29 (Grin29)
        [PSCustomObject]@{Algorithm = "cuckaroo_swap";       MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Params = ""} #Cuckaroo29s (Swap29)
        [PSCustomObject]@{Algorithm = "cuckatoo";            MinMemGB = 8; MinMemGBWin10 = 10; SecondaryIntensity = 0;  Fee = 2;    Params = ""} #Cuckatoo31 (Grin31)
        [PSCustomObject]@{Algorithm = "cuckoo_ae";           MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Params = ""} #Cuckoo29 (Aeternity)
        [PSCustomObject]@{Algorithm = "progpow_sero";        MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Params = ""} #Progpow92 (Sero)
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Main_Algorithm_Norm = Get-Algorithm ($_.Algorithm -Split "_" | Select-Object -Index 0); $_} | Where-Object {$Pools.$Main_Algorithm_Norm.Host} | ForEach-Object {
        $Main_Algorithm = $_.Algorithm -split '_' | Select-Object -Index 0
        $Secondary_Algorithm = $_.Algorithm -split '_' | Select-Object -Index 1
        $Algorithm = $_.Algorithm -replace "ethash(\dgb)", "ethash"
        $Fee = $_.Fee
        $Parameters = $_.Parameters
        if (([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) {
            $MinMemGB = $_.MinMemGBWin10
        }
        else {
            $MinMemGB = $_.MinMemGB
        }

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $_.Parameters $Miner_Device.Type_Vendor_Index
            }
            
            #define main algorithm protocol
            if ($Pools.$Main_Algorithm_Norm.Name = "Nicehash") {$Main_Protocol = "nicehash+tcp"}
            else {
                $Main_Protocol = "stratum+tcp"
                if ($Pools.$Main_Algorithm_Norm.SSL) {$Main_Protocol = "stratum+ssl"}
                if ($Main_Algorithm -like "ethash*") {$Main_Protocol = $Main_Protocol -replace "stratum", "ethnh"}
            }

            #Tensority: higher fee on Touring cards
            if ($Main_Algorithm_Norm -eq "Tensority" -and $Miner_Device.Model_Norm -match "^GTX16.+|^RTX20.+") {$Fee = 3}
            
            if ($Secondary_Algorithm) {
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm
                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) + @("$Main_Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @("$(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity})") | Select-Object) -join '-'

                #define secondary algorithm protocol
                $Secondary_Protocol = "stratum+tcp"
                if ($Pools.$Secondary_Protocol.SSL) {$Secondary_Protocol = "stratum+ssl"}
                if ($Secondary_Protocol -like "ethash*") {$Secondary_Protocol = $Secondary_Protocol -replace "stratum", "ethnh"}

                $Arguments_Secondary = " -do $($Secondary_Protocol)://$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -du $($Pools.$Secondary_Algorithm_Norm.User):$($Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -di $($_.SecondaryIntensity)"})"
                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = $Fee / 100; $Secondary_Algorithm_Norm = $Fee / 100}
                $IntervalMultiplier = 2
                $WarmupTime = 45
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = $Fee / 100}
                $Arguments_Secondary = ""
                $WarmupTime = 30
            }
            
            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("--api 127.0.0.1:$($Miner_Port) -a $Algorithm -o $($Main_Protocol)://$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -u $($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = $Miner_HashRates
                API        = "NBMiner"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = $Miner_Fees
                WarmupTime = $WarmupTime #seconds
            }
        }
    }
}