using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\nbminer.exe"
$HashSHA256 = "4AD3EBBA6F0DBB76186003CCB900B6CB313BF572ECC8DFEB4B637A9949DC7818"
$Uri = "https://github.com/NebuTech/NBMiner/releases/download/v26.0/NBMiner_26.0_Win.zip"
$ManualUri = "https://github.com/gangnamtestnet/progminer/releases"

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
    # [PSCustomObject]@{ Algorithm = "Ethash";               MinMemGB = 4; MinMemGBWin10 = 4; SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");     Command = " -a ethash" } #Ethash; ClaymoreDual & Phoenix are approx 10% faster          
    # [PSCustomObject]@{ Algorithm = "Ethash2GB";            MinMemGB = 2; MinMemGBWin10 = 2; SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");     Command = " -a ethash" } #Ethash2GB; ClaymoreDual & Phoenix are approx 10% faster          
    # [PSCustomObject]@{ Algorithm = "Ethash3GB";            MinMemGB = 3; MinMemGBWin10 = 3; SecondaryIntensity = 0;  Fee = 0.65; Vendor = @("NVIDIA");     Command = " -a ethash" } #Ethash3GB; ClaymoreDual & Phoenix are approx 10% faster          
    [PSCustomObject]@{ Algorithm = "CuckooBFC";            MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2; Vendor = @("NVIDIA");        Command = " -a bfc" } #CuckooBFC, new in 26.0
    [PSCustomObject]@{ Algorithm = "Cuckarood29";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2; Vendor = @("NVIDIA");        Command = " -a cuckarood" } #Cuckarood29
    [PSCustomObject]@{ Algorithm = "Cuckaroo29s";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2; Vendor = @("NVIDIA");        Command = " -a cuckaroo_swap" } #Cuckaroo29s (Swap29)
    [PSCustomObject]@{ Algorithm = "Cuckatoo31";           MinMemGB = 8; MinMemGBWin10 = 10; SecondaryIntensity = 0;  Fee = 2; Vendor = @("NVIDIA");        Command = " -a cuckatoo" } #Cuckatoo31 (Grin31)
    [PSCustomObject]@{ Algorithm = "Cuckoo29";             MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2; Vendor = @("NVIDIA");        Command = " -a cuckoo_ae" } #Cuckoo29 (Aeternity)
    [PSCustomObject]@{ Algorithm = "Eaglesong";            MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 2; Vendor = @("AMD", "NVIDIA"); Command = " -a eaglesong" } #Eaglesong (CBK), new in 25.0
    [PSCustomObject]@{ Algorithm = "Ethash;Eaglesong";     MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3; Vendor = @("NVIDIA");        Command = " -a eaglesong_ethash" } #Eaglesong (CBK) & Ethash, new in 25.0
    [PSCustomObject]@{ Algorithm = "Ethash2GB;Eaglesong";  MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 17; Fee = 3; Vendor = @("NVIDIA");        Command = " -a eaglesong_ethash" } #Eaglesong (CBK) & Ethash2GB, new in 25.0
    [PSCustomObject]@{ Algorithm = "Ethash3GB;Eaglesong";  MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 17; Fee = 3; Vendor = @("NVIDIA");        Command = " -a eaglesong_ethash" } #Eaglesong (CBK) & Ethash3GB, new in 25.0
    [PSCustomObject]@{ Algorithm = "ProgPoWSERO";          MinMemGB = 5; MinMemGBWin10 = 6;  SecondaryIntensity = 0;  Fee = 2; Vendor = @("AMD", "NVIDIA"); Command = " -a progpow_sero" } #Progpow92 (Sero)
    [PSCustomObject]@{ Algorithm = "ScryptSIPC";           MinMemGB = 1; MinMemGBWin10 = 1;  SecondaryIntensity = 0;  Fee = 2; Vendor = @("NVIDIA");        Command = " -a progpow_sero" } #ScryptSIPC, new in 24.3
    [PSCustomObject]@{ Algorithm = "Tensority";            MinMemGB = 1; MinMemGBWin10 = 1;  SecondaryIntensity = 0;  Fee = 2; Vendor = @("NVIDIA");        Command = " -a tensority" } #Tensority (BTM)
    [PSCustomObject]@{ Algorithm = "Ethash;Tensorityh";    MinMemGB = 4; MinMemGBWin10 = 4;  SecondaryIntensity = 17; Fee = 3; Vendor = @("NVIDIA");        Command = " -a tensority_ethash" } #Tensority (BTM) & Ethash
    [PSCustomObject]@{ Algorithm = "Ethash2GB;Tensority";  MinMemGB = 2; MinMemGBWin10 = 2;  SecondaryIntensity = 17; Fee = 3; Vendor = @("NVIDIA");        Command = " -a tensority_ethash" } #Tensority (BTM) & Ethash2GB
    [PSCustomObject]@{ Algorithm = "Ethash3GB;Tensority";  MinMemGB = 3; MinMemGBWin10 = 3;  SecondaryIntensity = 17; Fee = 3; Vendor = @("NVIDIA");        Command = " -a tensority_ethash" } #Tensority (BTM) & Ethash3GB
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Main_Algorithm_Norm = Get-Algorithm ($_.Algorithm -Split ";" | Select-Object -Index 0); $_ } | Where-Object { $_.Vendor -contains ($Device.Vendor | Select-Object -Unique) -and $Pools.$Main_Algorithm_Norm.Host } | ForEach-Object { 
        $Main_Algorithm = $_.Algorithm -split ';' | Select-Object -Index 0
        $Secondary_Algorithm = $_.Algorithm -split ';' | Select-Object -Index 1
        $Fee = $_.Fee

        if (([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) {  $MinMemGB = $_.MinMemGBWin10 }
        else {  $MinMemGB = $_.MinMemGB }

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index
            
            #define main algorithm protocol
            if ($Pools.$Main_Algorithm_Norm.Name -eq "Nicehash") { $Main_Protocol = "nicehash+tcp" }
            else { 
                $Main_Protocol = "stratum+tcp"
                if ($Pools.$Main_Algorithm_Norm.SSL) { $Main_Protocol = "stratum+ssl" }
                if ($Main_Algorithm -like "ethash*") { $Main_Protocol = $Main_Protocol -replace "stratum", "ethnh" }
            }

            #Tensority: higher fee on Touring cards
            if ($Main_Algorithm_Norm -eq "Tensority" -and $Miner_Device.Model -match "^GTX16.+|^RTX20.+") { $Fee = 3 }
            
            if ($Secondary_Algorithm) { 
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm
                $Miner_Name = (@($Name) + @(($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) -join '-') + @("$Main_Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @("$(if ($_.SecondaryIntensity -ge 0) { $_.SecondaryIntensity })") | Select-Object) -join '-'

                #define secondary algorithm protocol
                $Secondary_Protocol = "stratum+tcp"
                if ($Pools.$Secondary_Protocol.SSL) { $Secondary_Protocol = "stratum+ssl" }
                if ($Secondary_Protocol -like "ethash*") { $Secondary_Protocol = $Secondary_Protocol -replace "stratum", "ethnh" }

                $Arguments_Secondary = " -do $($Secondary_Protocol)://$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -du $($Pools.$Secondary_Algorithm_Norm.User):$($Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){ " -di $($_.SecondaryIntensity)" })"
                $Miner_HashRates = [PSCustomObject]@{ $Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week }
                $Miner_Fees = [PSCustomObject]@{ $Main_Algorithm_Norm = $Fee / 100; $Secondary_Algorithm_Norm = $Fee / 100 }
                $IntervalMultiplier = 2
                $WarmupTime = 45
            }
            else { 
                $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

                $Miner_HashRates = [PSCustomObject]@{ $Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week }
                $Miner_Fees = [PSCustomObject]@{ $Main_Algorithm_Norm = $Fee / 100 }
                $Arguments_Secondary = ""
                $WarmupTime = 30
            }
            
            if ($null -eq $Secondary_Algorithm -or $Pools.$Secondary_Algorithm_Norm.Host) { 
                [PSCustomObject]@{ 
                    Name       = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    Path       = $Path
                    HashSHA256 = $HashSHA256
                    Arguments  = ("$Command$CommonCommands --api 127.0.0.1:$($Miner_Port) -o $($Main_Protocol)://$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -u $($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ',')" -replace "\s+", " ").trim()
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
}
