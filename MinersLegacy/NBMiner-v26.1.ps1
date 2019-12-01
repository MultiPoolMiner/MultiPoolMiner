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
$Uri = "https://github.com/NebuTech/NBMiner/releases/download/v26.1/NBMiner_26.1_Win.zip"
$ManualUri = "https://github.com/gangnamtestnet/progminer/releases"
$DeviceEnumerator = "Type_Vendor_Index"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Devices = $Devices | Where-Object Type -EQ "GPU"

# Miner requires CUDA 9.1.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.1.00"
if ($Devices.Vendor -contains "NVIDIA" -and $CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    $Devices = $Devices | Where-Object Vendor -NE "NVIDIA"
}

$Commands = [PSCustomObject[]]@(
    # [PSCustomObject]@{ Algorithm = "Ethash";      SecondaryAlgorithm = "";          MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash" } #Ethash; ClaymoreDual & Phoenix are approx 10% faster          
    # [PSCustomObject]@{ Algorithm = "Ethash-2gb";  SecondaryAlgorithm = "";          MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash" } #Ethash2GB; ClaymoreDual & Phoenix are approx 10% faster          
    # [PSCustomObject]@{ Algorithm = "Ethash-3gb";  SecondaryAlgorithm = "";          MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash" } #Ethash3GB; ClaymoreDual & Phoenix are approx 10% faster          
    # [PSCustomObject]@{ Algorithm = "Ethash-4gb";  SecondaryAlgorithm = "";          MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash" } #Ethash4GB; ClaymoreDual & Phoenix are approx 10% faster          
    [PSCustomObject]@{ Algorithm = "CuckooBFC";   SecondaryAlgorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo bfc" } #CuckooBFC, new in 26.0
    [PSCustomObject]@{ Algorithm = "Cuckarood29"; SecondaryAlgorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckarood" } #Cuckarood29
    [PSCustomObject]@{ Algorithm = "Cuckaroo29s"; SecondaryAlgorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckaroo_swap" } #Cuckaroo29s (Swap29)
    [PSCustomObject]@{ Algorithm = "Cuckatoo31";  SecondaryAlgorithm = "";          MinMemGB = 8; MinMemGBWin10 = 10; SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckatoo" } #Cuckatoo31 (Grin31)
    [PSCustomObject]@{ Algorithm = "Cuckoo29";    SecondaryAlgorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckoo_ae" } #Cuckoo29 (Aeternity)
    [PSCustomObject]@{ Algorithm = "Eaglesong";   SecondaryAlgorithm = "";          MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong" } #Eaglesong (CBK), AMD new in 26.1
    [PSCustomObject]@{ Algorithm = "Ethash";      SecondaryAlgorithm = "Eaglesong"; MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong_ethash" } #Eaglesong (CBK) & Ethash, new in 26.1
    [PSCustomObject]@{ Algorithm = "Ethash-2gb";  SecondaryAlgorithm = "Eaglesong"; MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong_ethash" } #Eaglesong (CBK) & Ethash2GB, new in 26.1
    [PSCustomObject]@{ Algorithm = "Ethash-3gb";  SecondaryAlgorithm = "Eaglesong"; MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong_ethash" } #Eaglesong (CBK) & Ethash3GB, new in 26.1
    [PSCustomObject]@{ Algorithm = "Ethash-4gb";  SecondaryAlgorithm = "Eaglesong"; MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong_ethash" } #Eaglesong (CBK) & Ethash4GB, new in 26.1
    [PSCustomObject]@{ Algorithm = "ProgPoWSERO"; SecondaryAlgorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo progpow_sero" } #Progpow92 (Sero)
    [PSCustomObject]@{ Algorithm = "ScryptSIPC";  SecondaryAlgorithm = "";          MinMemGB = 1; MinMemGBWin10 = 1;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo sipc" } #ScryptSIPC, new in 24.3
    [PSCustomObject]@{ Algorithm = "Tensority";   SecondaryAlgorithm = "";          MinMemGB = 1; MinMemGBWin10 = 1;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo tensority" } #Tensority (BTM)
    [PSCustomObject]@{ Algorithm = "Ethash";      SecondaryAlgorithm = "Tensority"; MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo tensority_ethash" } #Tensority (BTM) & Ethash
    [PSCustomObject]@{ Algorithm = "Ethash-2gb";  SecondaryAlgorithm = "Tensority"; MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo tensority_ethash" } #Tensority (BTM) & Ethash2GB
    [PSCustomObject]@{ Algorithm = "Ethash-3gb";  SecondaryAlgorithm = "Tensority"; MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo tensority_ethash" } #Tensority (BTM) & Ethash3GB
    [PSCustomObject]@{ Algorithm = "Ethash-4gb";  SecondaryAlgorithm = "Tensority"; MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo tensority_ethash" } #Tensority (BTM) & Ethash4GB
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm -and $_.SecondaryAlgorithm -ne $SecondaryAlgorithm}; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Algorithm_Norm = @(@(Get-Algorithm ($_.Algorithm -split '-' | Select-Object -First 1) | Select-Object) + @($_.Algorithm -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'; $_ } | Where-Object { $_.Vendor -contains ($Device.Vendor | Select-Object -Unique) -and $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $Algorithm = $_.Algorithm
        $SecondaryAlgorithm = $_.SecondaryAlgorithm
        $Fee = $_.Fee

        if (([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) { $MinMemGB = $_.MinMemGBWin10 }
        else { $MinMemGB = $_.MinMemGB }

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.($DeviceEnumerator)
            
            if ($Miner_Device.Vendor -eq "AMD") { $Platform = " --platform 2" }
            if ($Miner_Device.Vendor -eq "NVIDIA") { $Platform = " --platform 1" }

            #define main algorithm protocol
            $Main_Protocol = "stratum+tcp"
            if ($Algorithm -match '^(ethash(-.+|))$') { $Secondary_Protocol = "ethproxy+tcp" }
            if ($Pools.$Algorithm_Norm.Name -match "MiningPoolHub-Algo|MiningPoolHub-Coin|Nicehash") { $Main_Protocol = "nicehash+tcp" }
            if ($Pools.$Algorithm_Norm.SSL) { $Main_Protocol = $Main_Protocol -replace "+tcp", "+ssl" }

            #Tensority: higher fee on Touring cards
            if ($Algorithm_Norm -eq "Tensority" -and $Miner_Device.Model -match "^GTX16.+|^RTX20.+") { $Fee = 3 }
            
            $Arguments = " --url $($Main_Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)"
            $HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            $Fees = [PSCustomObject]@{ $Algorithm_Norm = $Fee / 100 }
            $WarmupTime = 30

            if ($SecondaryAlgorithm) { 
                $SecondaryAlgorithm_Norm = @(@(Get-Algorithm ($_.SecondaryAlgorithm -split '-' | Select-Object -First 1) | Select-Object) + @($_.SecondaryAlgorithm -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'
                $Miner_Name = (@($Name) + @(($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) -join '-') + @("$Algorithm_Norm$SecondaryAlgorithm_Norm)") + @("$(if ($_.SecondaryIntensity -ge 0) { $_.SecondaryIntensity })") | Select-Object) -join '-'

                #define secondary algorithm protocol
                $Secondary_Protocol = "stratum+tcp"
                if ($SecondaryAlgorithm -match '^(ethash(-.+|))$') { $Secondary_Protocol = "ethproxy+tcp" }
                if ($Pools.$SecondaryAlgorithm_Norm.Name -match "MiningPoolHub-Algo|MiningPoolHub-Coin|Nicehash") { $Secondary_Protocol = "nicehash+tcp" }
                if ($Pools.$Secondary_Protocol.SSL) { $Secondary_Protocol = $Secondary_Protocol -replace "+tcp", "+ssl" }

                $Arguments += " -do $($Secondary_Protocol)://$($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -du $($Pools.$SecondaryAlgorithm_Norm.User):$($SecondaryAlgorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){ " -di $($_.SecondaryIntensity)" })"
                $HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week; $SecondaryAlgorithm_Norm = $Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week }
                $Fees = [PSCustomObject]@{ $Algorithm_Norm = $Fee / 100; $SecondaryAlgorithm_Norm = $Fee / 100 }
                $WarmupTime = 45
            }
            
            if (-not $SecondaryAlgorithm -or $Pools.$SecondaryAlgorithm_Norm.Host) { 
                [PSCustomObject]@{ 
                    Name       = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    Path       = $Path
                    HashSHA256 = $HashSHA256
                    Arguments  = ("$Command$CommonCommands$Platform --api 127.0.0.1:$($Miner_Port)$Arguments --devices $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.($DeviceEnumerator)) }) -join ',')" -replace "\s+", " ").trim()
                    HashRates  = $HashRates
                    API        = "NBMiner"
                    Port       = $Miner_Port
                    URI        = $Uri
                    Fees       = $Fees
                    WarmupTime = $WarmupTime #seconds
                }
            }
        }
    }
}
