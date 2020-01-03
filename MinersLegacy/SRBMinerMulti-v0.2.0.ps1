using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\SRBMiner-MULTI.exe"
$HashSHA256 = "ED778889BD39FFA37F5F7807F9B63D54225FBDF48E4687C460288E1ABBD187FC"
$Uri = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.2.0/SRBMiner-Multi-0-2-0.zip"
$ManualUri = "https://github.com/doktor83/SRBMiner-Multi"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

# Algorithm names are case sensitive!
$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "Blake2b";        MinMemGb = 1; Fee = 0;    Vendor = @("CPU", "AMD"); Command = " --algorithm blake2b" }
    [PSCustomObject]@{ Algorithm = "Blake2s";        MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm blake2s" }
    [PSCustomObject]@{ Algorithm = "CpuPower";       MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm cpupower" }
    [PSCustomObject]@{ Algorithm = "Eaglesong";      MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm eaglesong" }
    [PSCustomObject]@{ Algorithm = "Kangaroo12";     MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm k12" }
    [PSCustomObject]@{ Algorithm = "Mtp";            MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm mtp" }
    [PSCustomObject]@{ Algorithm = "Rainforestv2";   MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm rainforestv2" }
    [PSCustomObject]@{ Algorithm = "RandomX";        MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm randomx" }
    [PSCustomObject]@{ Algorithm = "RandomXArQmA";   MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm randomarq" }
    [PSCustomObject]@{ Algorithm = "RandomXloki";    MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm randomxl" }
    [PSCustomObject]@{ Algorithm = "RandomXwow";     MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm randomwow" }
    [PSCustomObject]@{ Algorithm = "Yescrypt";       MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm yescrypt" }
    [PSCustomObject]@{ Algorithm = "Yescryptr16";    MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yescryptr16" }
    [PSCustomObject]@{ Algorithm = "Yescryptr32";    MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yescryptr32" }
    [PSCustomObject]@{ Algorithm = "Yescryptr8";     MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yescryptr8" }
    [PSCustomObject]@{ Algorithm = "Yespower";       MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespower" }
    [PSCustomObject]@{ Algorithm = "Yespower2b";     MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespower2b" }
    [PSCustomObject]@{ Algorithm = "Yespowerlitb";   MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowerlitb" }
    [PSCustomObject]@{ Algorithm = "Yespowerltncg";  MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowerltncg" }
    [PSCustomObject]@{ Algorithm = "Yespowerr16";    MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowerr16" }
    [PSCustomObject]@{ Algorithm = "Yespowersugar";  MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowersugar" }
    [PSCustomObject]@{ Algorithm = "Yespowerurx";    MinMemGb = 1; Fee = 0;    Vendor = @("CPU")       ; Command = " --algorithm yespowerurx" }
)

#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " --disable-tweaking" }

$Devices = $Devices | Where-Object { $_.Type -EQ "CPU" -or $_.Vendor -EQ "AMD" }
$Devices | Select-Object Model, Type, Vendor  -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Model -EQ $_.Model| Where-Object Type -EQ $_.Type | Where-Object Vendor -EQ $_.Vendor)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host -and (($Device.Type | Select-Object -Unique) -in $_.Vendor -or ($Device.Vendor | Select-Object -Unique) -in $_.Vendor) } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB -or $_.Type -eq "CPU" })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("algorithm") -DeviceIDs $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{ 
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands --api-enable --api-port $($Miner_Port)$(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") { " --nicehash true" }) --tls $(([String]($Pools.$Algorithm_Norm.SSL)).ToLower()) --pool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --wallet $($Pools.$Algorithm_Norm.User) --password $($Pools.$Algorithm_Norm.Pass) $(if ($Miner_Device.Type -eq "GPU") { "--gpu-id $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Slot) }) -join ',') --disable-cpu" } else { "--disable-gpu" })" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                API        = "SRBMiner"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{ $Algorithm_Norm = $_.Fee  / 100 }
                WarmupTime = 60 #seconds
            }
        }
    }
}