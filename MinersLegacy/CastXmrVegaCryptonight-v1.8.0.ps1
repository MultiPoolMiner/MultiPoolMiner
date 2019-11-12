using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\cast_xmr-vega.exe"
$HashSHA256 = "169C1DE91F6FB3402C9843A90997E3CD82D3F9BBF74EEA9C99F998A2CEEDC658"
$Uri = "https://github.com/glph3k/cast_xmr/releases/download/v180/cast_xmr-vega-win64_180.zip"
$ManualUri = "http://www.gandalph3000.com"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "CryptonightV7";        MinMemGB = 2; Command = " -a 1"} #CryptonightV7
    [PSCustomObject]@{Algorithm = "CryptonightHeavy";     MinMemGB = 4; Command = " -a 2"} #CryptonightHeavy
    [PSCustomObject]@{Algorithm = "CryptonightLite";      MinMemGB = 1; Command = " -a 3"} #CryptonightLite
    [PSCustomObject]@{Algorithm = "CryptonightLiteV7";    MinMemGB = 1; Command = " -a 4"} #CryptonightLiteV7
    [PSCustomObject]@{Algorithm = "CryptonightHeavyTube"; MinMemGB = 4; Command = " -a 5"} #CryptonightHeavyTube
    [PSCustomObject]@{Algorithm = "CryptonightXtl";       MinMemGB = 2; Command = " -a 6"} #CryptonightXtl
    [PSCustomObject]@{Algorithm = "CryptonightHeavyXhv";  MinMemGB = 4; Command = " -a 7"} #CryptonightHeavyXhv
    [PSCustomObject]@{Algorithm = "CryptonightFast";      MinMemGB = 2; Command = " -a 8"} #CryptonightFast
    [PSCustomObject]@{Algorithm = "CryptonightRto";       MinMemGB = 2; Command = " -a 9"} #CryptonightFest (not to be confused with CryptonightFast), new with 1.50
    [PSCustomObject]@{Algorithm = "CryptonightV8";        MinMemGB = 2; Command = " -a 10"} #CryptonightV8, new with 1.50
    [PSCustomObject]@{Algorithm = "CryptonightXfh";       MinMemGB = 2; Command = " -a 11"} #CryptoNightXfh, new with 1.65

    # ASIC only (09/07/2018)
    #[PSCustomObject]@{Algorithm_Norm = "Cryptonight";          AlgoNumber = 0; MinMemGB = 2; Commands = ""} #Cryptonight
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --fastjobswitch --intensity -1"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp"} | ForEach-Object {
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB -and $_.Model -match "^Baffin.*|^Ellesmere.*|^Polaris.*|^Vega.*|^gfx900.*"})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands --remoteaccess --remoteport $($Miner_Port) -S $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --opencl $($Miner_Device | Select-Object -First 1 -ExpandProperty PlatformId) $(if ($Pools.$Algorithm_Norm.Name -ne "NiceHash") {" --nonicehash"}) -G $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Cast"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 1.5 / 100}
            }
        }
    }
}
