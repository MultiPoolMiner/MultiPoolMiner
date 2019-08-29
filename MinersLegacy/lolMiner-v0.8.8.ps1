using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\lolminer.exe"
$HashSHA256 = "4B6916F159A10759CE15C9097F7EBD48FA07BE152B01451135BFA83BB2D1C794"
$Uri = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/0.8.8/lolMiner_v088_Win64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash1445";    MinMemGB = 1.85; Vendor = @("AMD", "NVIDIA"); Command = " --coin AUTO144_5"}
    [PSCustomObject]@{Algorithm = "Equihash1927";    MinMemGB = 3.0;  Vendor = @("AMD" <#, "NVIDIA"#>); Command = " --coin AUTO192_7"} # MiniZEquihash-v1.5p is faster on NVIDIA
    [PSCustomObject]@{Algorithm = "Equihash2109";    MinMemGB = 1.0;  Vendor = @("AMD", "NVIDIA"); Command = " --coin AOIN"} # new with 0.6 alpha 3
    [PSCustomObject]@{Algorithm = "Equihash965";     MinMemGB = 1.35; Vendor = @("AMD" <#, "NVIDIA"#>); Command = " --coin MNX"} # Ewbf2Equihash-v0.6 is faster on NVIDIA
    [PSCustomObject]@{Algorithm = "EquihashR12540";  MinMemGB = 3.00; Vendor = @("AMD" <#, "NVIDIA"#>); Command = " --coin ZEL"} # MiniZEquihash-v1.5p is faster on NVIDIA
    [PSCustomObject]@{Algorithm = "EquihashR150503"; MinMemGB = 2.75; Vendor = @("AMD", "NVIDIA"); Command = " --coin BEAM"}
    [PSCustomObject]@{Algorithm = "Cuckarood29";     MinMemGB = 4.0;  Vendor = @("AMD", "NVIDIA"); Command = " --coin GRIN-AD29"} # new with 0.8
    [PSCustomObject]@{Algorithm = "Cuckatoo31";      MinMemGB = 4.0;  Vendor = @("AMD", "NVIDIA"); Command = " --coin GRIN-AT31"} # new with 0.8
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --workbatch HIGH --shortstats 5 --digits 3"}

$Devices = $Devices | Where-Object Type -EQ "GPU"
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$_.Vendor -contains ($Device.Vendor_ShortName | Select-Object -Unique) -and $Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("coins") -DeviceIDs $Miner_Device.Type_Vendor_Index

            #Disable_memcheck
            if ($Miner_Device.Vendor -eq "NVIDIA Corporation" -and $Algorithm_Norm -ne "Equihash965") {$Command += " --disable_memcheck 1"}

            [PSCustomObject]@{
                Name             = $Miner_Name
                BaseName         = $Miner_BaseName
                Version          = $Miner_Version
                DeviceName       = $Miner_Device.Name
                Path             = $Path
                HashSHA256       = $HashSHA256
                Arguments        = ("$Command$CommonCommands --pool $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.pass) --apiport $Miner_Port$(if ($Pools.$Algorithm_Norm.SSL) {" --tls 1 "} else {" --tls 0 "}) --devices $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Slot}) -join ',')").trim()
                HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API              = "lolMinerApi"
                Port             = $Miner_Port
                URI              = $Uri
                Fees             = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
                WarmupTime       = 45 #seconds
            }
        }
    }
}
