using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\miner.exe"
$HashSHA256 = "F400F66CDAF1B54BB25661D3FA8116B490E19A6E055F388F5E493754DF0159D7"
$Uri = "https://github.com/develsoftware/GMinerRelease/releases/download/1.92/gminer_1_92_windows64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5034735.0"
$DeviceEnumerator = "Type_Vendor_Slot"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Main_Algorithm = "BFC";            Secondary_Algorithm = "";          MinMemGB = 4.0; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo bfc" } #new in v1.69
    [PSCustomObject]@{ Main_Algorithm = "Cuckaroo29";     Secondary_Algorithm = "";          MinMemGB = 4.0; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo cuckaroo29" } #new in v1.19; Cuckaroo29 / Grin
    [PSCustomObject]@{ Main_Algorithm = "Cuckaroo29s";    Secondary_Algorithm = "";          MinMemGB = 4.0; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo cuckaroo29s" } #new in v1.34; Cuckaroo29s / Swap
    [PSCustomObject]@{ Main_Algorithm = "Cuckatoo31";     Secondary_Algorithm = "";          MinMemGB = 7.4; Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo cuckatoo31" } #new in v1.31; Cuckatoo31 / Grin
    [PSCustomObject]@{ Main_Algorithm = "Cuckarood29";    Secondary_Algorithm = "";          MinMemGB = 1.0; Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo grin29" } #new in v1.51
    [PSCustomObject]@{ Main_Algorithm = "Cuckoo29";       Secondary_Algorithm = "";          MinMemGB = 4.0; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo cuckoo29" } #new in v1.24; Cuckoo29 / Aeternity
    [PSCustomObject]@{ Main_Algorithm = "CuckooBFC";      Secondary_Algorithm = "";          MinMemGB = 1.0; Fee = 3;    Vendor = @("AMD", "NVIDIA"); Command = " --algo bfc" } #new in v1.69; CuckooBFC
    [PSCustomObject]@{ Main_Algorithm = "Eaglesong";      Secondary_Algorithm = "";          MinMemGB = 0.8; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo ckb" } #new in v1.73
    [PSCustomObject]@{ Main_Algorithm = "Equihash965";    Secondary_Algorithm = "";          MinMemGB = 0.8; Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo equihash96_5" } #new in v1.13
    [PSCustomObject]@{ Main_Algorithm = "Equihash1254";   Secondary_Algorithm = "";          MinMemGB = 1.0; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo equihash125_4" } #new in v1.46; ZelCash
    [PSCustomObject]@{ Main_Algorithm = "Equihash1445";   Secondary_Algorithm = "";          MinMemGB = 1.8; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo equihash144_5" }
    [PSCustomObject]@{ Main_Algorithm = "Equihash1927";   Secondary_Algorithm = "";          MinMemGB = 2.8; Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo equihash192_7" }
    [PSCustomObject]@{ Main_Algorithm = "Equihash2109";   Secondary_Algorithm = "";          MinMemGB = 1.0; Fee = 2;    Vendor = @("NVIDIA");        Command = " --algo equihash210_9" } #new in v1.09
    [PSCustomObject]@{ Main_Algorithm = "EquihashR15053"; Secondary_Algorithm = "";          MinMemGB = 4.0; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo BeamHashII --OC1" } #new in v1.55
    [PSCustomObject]@{ Main_Algorithm = "Ethash";         Secondary_Algorithm = "";          MinMemGB = 4.0; Fee = 0.65; Vendor = @("NVIDIA");        Command = " --algo ethash --proto stratum" } #new in v1.71
#    [PSCustomObject]@{ Main_Algorithm = "Ethash";         Secondary_Algorithm = "Eaglesong"; MinMemGB = 4.0; Fee = 3;    Vendor = @("NVIDIA");        Command = " --algo ethash+eaglesong --proto stratum" } #new in v1.75
    [PSCustomObject]@{ Main_Algorithm = "Grimm";          Secondary_Algorithm = "";          MinMemGB = 1.0; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo grimm" } #new in v1.54; Grimm
    [PSCustomObject]@{ Main_Algorithm = "vds";            Secondary_Algorithm = "";          MinMemGB = 1.0; Fee = 2;    Vendor = @("AMD", "NVIDIA"); Command = " --algo vds" } #new in v1.43; Vds / V-Dimension
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Main_Algorithm = $_.Main_Algorithm; $Commands = $Commands | Where-Object { $_.Main_Algorithm -ne $Main_Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " --watchdog 0 --nvml 0" }

$Devices = $Devices | Where-Object Type -EQ "GPU"
$Devices | Select-Object Type, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Type -EQ $_.Type | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Main_Algorithm_Norm = Get-Algorithm $_.Main_Algorithm; $_ } | Where-Object { $_.Vendor -contains ($Device.Vendor | Select-Object -Unique) -and $Pools.$Main_Algorithm_Norm.Host } | ForEach-Object { 
        $Secondary_Algorithm = $_.Secondary_Algorithm
        $MinMemGB = $_.MinMemGB
        
        #Windows 10 requires 1 GB extra
        if ($_.Main_Algorithm -match "cuckaroo29|cuckarood29|cuckaroo29s|cuckoo*" -and ([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) { $MinMemGB += 1 }

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.($DeviceEnumerator)
            
            if ($Miner_Device.Vendor -eq "AMD") { $Platform = " --cuda 0 --opencl 1" }
            if ($Miner_Device.Vendor -eq "NVIDIA") { $Platform = " --cuda 1 --opencl 0" }

            Switch ($Main_Algorithm_Norm) { 
                "Equihash1445"   { $Pers = " --pers $(Get-AlgoCoinPers -Algorithm $Main_Algorithm_Norm -CoinName $Pools.$Main_Algorithm_Norm.CoinName -Default "auto")" }
                "Equihash1927"   { $Pers = " --pers $(Get-AlgoCoinPers -Algorithm $Main_Algorithm_Norm -CoinName $Pools.$Main_Algorithm_Norm.CoinName -Default "auto")" }
                Default          { $Pers = "" }
            }

            $Arguments = "$Pers$(if ($Pools.$Main_Algorithm_Norm.SSL) { " --ssl --ssl_verification 0" }) --server $($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) --user $($Pools.$Main_Algorithm_Norm.User) --pass $($Pools.$Main_Algorithm_Norm.Pass)"
            $Fees = [PSCustomObject]@{ $Main_Algorithm_Norm = $_.Fee / 100 }
            $HashRates = [PSCustomObject]@{ $Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week }

            if ($Secondary_Algorithm) { 
                $Miner_Name = (@($Name) + @(($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) -join '-') + @("$Main_Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @("$(if ($_.SecondaryIntensity -ge 0) { $_.SecondaryIntensity })") | Select-Object) -join '-'
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                $Arguments += "$(if ($Pools.$Main_Algorithm_Norm.SSL) { " --dssl --dssl_verification 0" }) --dserver $($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) --duser $($Pools.$Secondary_Algorithm_Norm.User):$($Secondary_Algorithm_Norm.Pass)"
                $Fees = [PSCustomObject]@{ $Main_Algorithm_Norm = $Fee / 100; $Secondary_Algorithm_Norm = $Fee / 100 }
                $HashRates = [PSCustomObject]@{ $Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week }
            }

            if (-not $Secondary_Algorithm -or $Secondary_Algorithm_Norm.Host) {
                [PSCustomObject]@{ 
                    Name       = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    Path       = $Path
                    HashSHA256 = $HashSHA256
                    Arguments  = ("$Command$CommonCommands$Platform --api $($Miner_Port)$Arguments --devices $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.($DeviceEnumerator)) }) -join ' ')" -replace "\s+", " ").trim()
                    HashRates  = $HashRates
                    API        = "Gminer"
                    Port       = $Miner_Port
                    URI        = $Uri
                    Fees       = $Fees
                    WarmupTime = 45 #seconds
                }
            }
        }
    }
}
