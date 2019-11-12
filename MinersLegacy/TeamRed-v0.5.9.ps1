using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\teamredminer.exe"
$HashSHA256 = "652E42705B6747A0B32B3AD1706ACEC00B5C5CC7C12F2627F0018D969A46AB98"
$Uri = "https://github.com/todxx/teamredminer/releases/download/0.5.9/teamredminer-v0.5.9-win.zip"
$ManualUri = "https://github.com/todxx/teamredminer"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Argon2idChukwa";     Fee = 2.5; MinMemGB = 2.0; Command = " --algo=trtl_chukwa"} #Argon2idChukwa (TurtleCoin), new in 0.5.8
    [PSCustomObject]@{Algorithm = "CryptonightConceal"; Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cn_conceal --auto_tune=NONE"} #CryptonightConceal, new in 0.5.7
    [PSCustomObject]@{Algorithm = "CryptonightHeavy";   Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cn_heavy --auto_tune=NONE"} #CryptonightHeavy, new in 0.5.4
    [PSCustomObject]@{Algorithm = "CryptonightHaven";   Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cn_haven --auto_tune=NONE"} #CryptonightHaven, new in 0.5.4
    [PSCustomObject]@{Algorithm = "CryptonightSaber";   Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cn_saber --auto_tune=NONE"} #CryptonightHeavyTube, new in 0.5.4
    [PSCustomObject]@{Algorithm = "CryptonightR";       Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cnr --auto_tune=NONE"} #CryptonightR, new in 0.4.1
    [PSCustomObject]@{Algorithm = "CryptonightV8";      Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cnv8 --auto_tune=NONE"} #CryptonightV8, new in 0.3.5
    [PSCustomObject]@{Algorithm = "CryptonightDouble";  Fee = 2.5; MinMemGB = 4.0; Command = " --algo=cnv8_dbl --auto_tune=NONE"} #CryptonightDouble, new in 0.4.2
    [PSCustomObject]@{Algorithm = "CryptonightHalf";    Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cnv8_half --auto_tune=NONE"} #CryptonightHalf, new in 0.4.2
    [PSCustomObject]@{Algorithm = "CryptonightTurtle";  Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cnv8_trtl --auto_tune=NONE"} #CryptonightTurtle, new in 0.4.3
    [PSCustomObject]@{Algorithm = "CryptonightRwz";     Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cnv8_rwz --auto_tune=NONE"} #CryptonightRwz, new in 0.4.2
    [PSCustomObject]@{Algorithm = "CryptonightUpx";     Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cnv8_upx2 --auto_tune=NONE"} #CryptonightUpx, new in 0.4.2
    [PSCustomObject]@{Algorithm = "Cuckarood29";        Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cuckarood29_grin"} #Cuckarood29, new in 0.5.7
    [PSCustomObject]@{Algorithm = "Cuckatoo31";         Fee = 2.5; MinMemGB = 2.0; Command = " --algo=cuckatoo31_grin"} #Cuckatoo31, new in 0.5.5
    [PSCustomObject]@{Algorithm = "Lyra2RE3";           Fee = 2.5; MinMemGB = 2.0; Command = " --algo=lyra2rev3"} #Lyra2rev3, new in 0.3.9
#    [PSCustomObject]@{Algorithm = "Lyra2z";             Fee = 3;   MinMemGB = 2.0; Command = " --algo=lyra2z"} #Lyra2Z, new in 0.3.5, unprofitable
    [PSCustomObject]@{Algorithm = "Mtp";                Fee = 2.5; MinMemGB = 4.0; Command = " --algo=mtp"} #MTP (Zcoin), new in 0.5.3
    [PSCustomObject]@{Algorithm = "MtpNicehash";        Fee = 2.5; MinMemGB = 4.0; Command = " --algo=mtp"} #MTP (Zcoin), new in 0.5.3
    [PSCustomObject]@{Algorithm = "Phi2";               Fee = 3;   MinMemGB = 2.0; Command = " --algo=phi2"} #Phi2, new in 0.3.5
    [PSCustomObject]@{Algorithm = "Phi2-Lux";           Fee = 3;   MinMemGB = 2.0; Command = " --algo=phi2"} #Phi2-Lux, new in 0.3.5
    [PSCustomObject]@{Algorithm = "X16r";               Fee = 2.5; MinMemGB = 4.0; Command = " --algo=x16r"} #X16r, new in 0.5.0
    [PSCustomObject]@{Algorithm = "X16rv2";             Fee = 2.5; MinMemGB = 4.0; Command = " --algo=x16rv2"} #X16rv2, new in 0.5.9
    [PSCustomObject]@{Algorithm = "X16s";               Fee = 2.5; MinMemGB = 2.0; Command = " --algo=x16s"} #X16r, new in 0.5.0
    [PSCustomObject]@{Algorithm = "X16rt";              Fee = 2.5; MinMemGB = 2.0; Command = " --algo=x16rt "} #X16Rt new in 0.5.0
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --watchdog_script"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {$_.Type -eq "CPU" -or ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

            Switch ($Algorithm_Norm) {
                "C11"    {$WarmupTime = 60}
                default  {$WarmupTime = 45}
            }
    
            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands --api_listen=127.0.0.1:$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass) --platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Xgminer"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $_.Fee / 100}
                WarmupTime = $WarmupTime #seconds
            }
        }
    }
}
