using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\SRBMiner-MULTI.exe"
$HashSHA256 = ""
$Uri = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.1.4/SRBMiner-Multi-0-1-4.zip"
$ManualUri = "https://github.com/doktor83/SRBMiner-Multi/releases"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "argon2d"; MinMemGB = 6; Command = " -a argon2d" } #Argon2dDYN
)
# Algorithm names are case sensitive!
$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "CpuPower";       MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm cpupower" }
    [PSCustomObject]@{ Algorithm = "Yescryptr16";    MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yescryptr16" }
    [PSCustomObject]@{ Algorithm = "Yescryptr32";    MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yescryptr32" }
    [PSCustomObject]@{ Algorithm = "Yescryptr8";     MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yescryptr8" }
    [PSCustomObject]@{ Algorithm = "Yespower";       MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespower" }
    [PSCustomObject]@{ Algorithm = "Yespower2b";     MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespower2b" }
    [PSCustomObject]@{ Algorithm = "Yespowerlitb";   MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowerlitb" }
    [PSCustomObject]@{ Algorithm = "Yespowerltncg";  MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowerltncg" }
    [PSCustomObject]@{ Algorithm = "Yespowerr16";    MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowerr16" }
    [PSCustomObject]@{ Algorithm = "Yespowersugar";  MinMemGb = 1; Fee = 0.85; Vendor = @("CPU")       ; Command = " --algorithm yespowersugar" }
    [PSCustomObject]@{ Algorithm = "Yesyespowerurx"; MinMemGb = 1; Fee = 0;    Vendor = @("CPU")       ; Command = " --algorithm yesyespowerurx" }
    [PSCustomObject]@{ Algorithm = "Blake2b";        MinMemGb = 1; Fee = 0;    Vendor = @("CPU", "AMD"); Command = " --algorithm blake2b" }
    [PSCustomObject]@{ Algorithm = "Blake2s";        MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm blake2s" }
    [PSCustomObject]@{ Algorithm = "Eaglesong";      MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm eaglesong" }
    [PSCustomObject]@{ Algorithm = "Kangaroo12";     MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm k12" }
    [PSCustomObject]@{ Algorithm = "Mtp";            MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm mtp" }
    [PSCustomObject]@{ Algorithm = "Rainforestv2";   MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm rainforestv2" }
    [PSCustomObject]@{ Algorithm = "Yescrypt";       MinMemGb = 1; Fee = 0.85; Vendor = @("CPU", "AMD"); Command = " --algorithm yescrypt" }
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices = $Devices | Where-Object { $_.Type -EQ "CPU" -or $_.Vendor -EQ "Advanced Micro Devices, Inc." }
$Devices | Select-Object Model, Type, Vendor  -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Model -EQ $_.Model| Where-Object Type -EQ $_.Type | Where-Object Vendor -EQ $_.Vendor)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1)

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host -and (($Device.Type | Select-Object -Unique) -in $_.Vendor -or ($Device.Vendor_ShortName | Select-Object -Unique) -in $_.Vendor) } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB -or $_.Type -eq "CPU" })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object { $Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("algorithm") -DeviceIDs $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{ 
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands --api-enable --api-port $($Miner_Port)$(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") { " --nicehash true" }) --tls $(([String]($Pools.$Algorithm_Norm.SSL)).ToLower()) --pool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --wallet $($Pools.$Algorithm_Norm.User) --password $($Pools.$Algorithm_Norm.Pass) $(if ($Miner_Device.Type -eq "GPU") { "--gpu-id $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ',') --disable-cpu" } else { "--disable-gpu" })" -replace "\s+", " ").trim()
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