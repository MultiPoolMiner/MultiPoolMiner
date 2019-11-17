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
    # [PSCustomObject]@{ Main_Algorithm = "Ethash";      Secondary_Algorithm = "";          MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash" } #Ethash; ClaymoreDual & Phoenix are approx 10% faster          
    # [PSCustomObject]@{ Main_Algorithm = "Ethash2GB";   Secondary_Algorithm = "";          MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash" } #Ethash2GB; ClaymoreDual & Phoenix are approx 10% faster          
    # [PSCustomObject]@{ Main_Algorithm = "Ethash3GB";   Secondary_Algorithm = "";          MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash" } #Ethash3GB; ClaymoreDual & Phoenix are approx 10% faster          
    [PSCustomObject]@{ Main_Algorithm = "CuckooBFC";   Secondary_Algorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo bfc" } #CuckooBFC, new in 26.0
    [PSCustomObject]@{ Main_Algorithm = "Cuckarood29"; Secondary_Algorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckarood" } #Cuckarood29
    [PSCustomObject]@{ Main_Algorithm = "Cuckaroo29s"; Secondary_Algorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckaroo_swap" } #Cuckaroo29s (Swap29)
    [PSCustomObject]@{ Main_Algorithm = "Cuckatoo31";  Secondary_Algorithm = "";          MinMemGB = 8; MinMemGBWin10 = 10; SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckatoo" } #Cuckatoo31 (Grin31)
    [PSCustomObject]@{ Main_Algorithm = "Cuckoo29";    Secondary_Algorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckoo_ae" } #Cuckoo29 (Aeternity)
    [PSCustomObject]@{ Main_Algorithm = "Eaglesong";   Secondary_Algorithm = "";          MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong" } #Eaglesong (CBK), AMD new in 26.1
    [PSCustomObject]@{ Main_Algorithm = "Ethash";      Secondary_Algorithm = "Eaglesong"; MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong_ethash" } #Eaglesong (CBK) & Ethash, new in 26.1
    [PSCustomObject]@{ Main_Algorithm = "Ethash2GB";   Secondary_Algorithm = "Eaglesong"; MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong_ethash" } #Eaglesong (CBK) & Ethash2GB, new in 26.1
    [PSCustomObject]@{ Main_Algorithm = "Ethash3GB";   Secondary_Algorithm = "Eaglesong"; MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo eaglesong_ethash" } #Eaglesong (CBK) & Ethash3GB, new in 26.1
    [PSCustomObject]@{ Main_Algorithm = "ProgPoWSERO"; Secondary_Algorithm = "";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo progpow_sero" } #Progpow92 (Sero)
    [PSCustomObject]@{ Main_Algorithm = "ScryptSIPC";  Secondary_Algorithm = "";          MinMemGB = 1; MinMemGBWin10 = 1;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo sipc" } #ScryptSIPC, new in 24.3
    [PSCustomObject]@{ Main_Algorithm = "Tensority";   Secondary_Algorithm = "";          MinMemGB = 1; MinMemGBWin10 = 1;  SecondaryIntensity = 0;  Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo tensority" } #Tensority (BTM)
    [PSCustomObject]@{ Main_Algorithm = "Ethash";      Secondary_Algorithm = "Tensority"; MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo tensority_ethash" } #Tensority (BTM) & Ethash
    [PSCustomObject]@{ Main_Algorithm = "Ethash2GB";   Secondary_Algorithm = "Tensority"; MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo tensority_ethash" } #Tensority (BTM) & Ethash2GB
    [PSCustomObject]@{ Main_Algorithm = "Ethash3GB";   Secondary_Algorithm = "Tensority"; MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 17; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo tensority_ethash" } #Tensority (BTM) & Ethash3GB
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Main_Algorithm = $_.Main_Algorithm; $Commands = $Commands | Where-Object { $_.Main_Algorithm -ne $Main_Algorithm -and $_.Secondary_Algorithm -ne $Secondary_Algorithm}; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Main_Algorithm_Norm = Get-Algorithm $_.Main_Algorithm; $_ } | Where-Object { $_.Vendor -contains ($Device.Vendor | Select-Object -Unique) -and $Pools.$Main_Algorithm_Norm.Host } | ForEach-Object { 
        $Main_Algorithm = $_.Main_Algorithm
        $Secondary_Algorithm = $_.Secondary_Algorithm
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
            if ($Main_Algorithm -like "ethash*") { $Secondary_Protocol = "ethproxy+tcp" }
            if ($Pools.$Main_Algorithm_Norm.Name -match "MiningPoolHub-Algo|MiningPoolHub-Coin|Nicehash") { $Main_Protocol = "nicehash+tcp" }
            if ($Pools.$Main_Algorithm_Norm.SSL) { $Main_Protocol = $Main_Protocol -replace "+tcp", "+ssl" }

            #Tensority: higher fee on Touring cards
            if ($Main_Algorithm_Norm -eq "Tensority" -and $Miner_Device.Model -match "^GTX16.+|^RTX20.+") { $Fee = 3 }
            
            $Arguments = " --url $($Main_Protocol)://$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) --user $($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)"
            $HashRates = [PSCustomObject]@{ $Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week }
            $Fees = [PSCustomObject]@{ $Main_Algorithm_Norm = $Fee / 100 }
            $WarmupTime = 30

            if ($Secondary_Algorithm) { 
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm
                $Miner_Name = (@($Name) + @(($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) -join '-') + @("$Main_Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @("$(if ($_.SecondaryIntensity -ge 0) { $_.SecondaryIntensity })") | Select-Object) -join '-'

                #define secondary algorithm protocol
                $Secondary_Protocol = "stratum+tcp"
                if ($Secondary_Algorithm -like "ethash*") { $Secondary_Protocol = "ethproxy+tcp" }
                if ($Pools.$Secondary_Algorithm_Norm.Name -match "MiningPoolHub-Algo|MiningPoolHub-Coin|Nicehash") { $Secondary_Protocol = "nicehash+tcp" }
                if ($Pools.$Secondary_Protocol.SSL) { $Secondary_Protocol = $Secondary_Protocol -replace "+tcp", "+ssl" }

                $Arguments += " -do $($Secondary_Protocol)://$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -du $($Pools.$Secondary_Algorithm_Norm.User):$($Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){ " -di $($_.SecondaryIntensity)" })"
                $HashRates = [PSCustomObject]@{ $Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week }
                $Fees = [PSCustomObject]@{ $Main_Algorithm_Norm = $Fee / 100; $Secondary_Algorithm_Norm = $Fee / 100 }
                $WarmupTime = 45
            }
            
            if (-not $Secondary_Algorithm -or $Pools.$Secondary_Algorithm_Norm.Host) { 
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
