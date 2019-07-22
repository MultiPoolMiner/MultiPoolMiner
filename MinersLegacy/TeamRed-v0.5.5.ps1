using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\teamredminer.exe"
$HashSHA256 = "934EE7F13BFCB72838B81309E9A091944C3966FF55934213EBD666C912C42B19"
$Uri = "https://github.com/todxx/teamredminer/releases/download/0.5.5/teamredminer-v0.5.5-win.zip"
$ManualUri = "https://github.com/todxx/teamredminer"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "cn_heavy";   Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightHeavy, new in 0.5.4
        [PSCustomObject]@{Algorithm = "cn_haven";   Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightHeavyHaven, new in 0.5.4
        [PSCustomObject]@{Algorithm = "cn_saber";   Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightHeavyTube, new in 0.5.4
        [PSCustomObject]@{Algorithm = "cnr";        Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightR, new in 0.4.1
        [PSCustomObject]@{Algorithm = "cnv8";       Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightV8, new in 0.3.5
        [PSCustomObject]@{Algorithm = "cnv8_dbl";   Fee = 2.5; MinMemGB = 4.0; Parameters = " --auto_tune=NONE"} #CryptonightDoubleV8, new in 0.4.2
        [PSCustomObject]@{Algorithm = "cnv8_half";  Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightHalfV8, new in 0.4.2
        [PSCustomObject]@{Algorithm = "cnv8_trtl";  Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightTurtle, new in 0.4.3
        [PSCustomObject]@{Algorithm = "cnv8_rwz";   Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightRwzV8, new in 0.4.2
        [PSCustomObject]@{Algorithm = "cnv8_upx2";  Fee = 2.5; MinMemGB = 2.0; Parameters = " --auto_tune=NONE"} #CryptonightUpx2V8, new in 0.4.2
        [PSCustomObject]@{Algorithm = "cuckatoo31"; Fee = 2.5; MinMemGB = 2.0; Parameters = ""} #Cuckatoo31, new in 0.5.5
        [PSCustomObject]@{Algorithm = "lyra2rev3";  Fee = 2.5; MinMemGB = 2.0; Parameters = ""} #Lyra2rev3, new in 0.3.9
        [PSCustomObject]@{Algorithm = "lyra2z";     Fee = 3;   MinMemGB = 2.0; Parameters = ""} #Lyra2Z, new in 0.3.5
        [PSCustomObject]@{Algorithm = "mtp";        Fee = 2.5; MinMemGB = 2.0; Parameters = ""} #MTP (Zcoin), new in 0.5.3
        [PSCustomObject]@{Algorithm = "phi2";       Fee = 3;   MinMemGB = 2.0; Parameters = ""} #Phi2, new in 0.3.5
        [PSCustomObject]@{Algorithm = "x16r";       Fee = 2.5; MinMemGB = 4.0; Parameters = ""} #X16r, new in 0.5.0
        [PSCustomObject]@{Algorithm = "x16s";       Fee = 2.5; MinMemGB = 2.0; Parameters = ""} #X16r, new in 0.5.0
        [PSCustomObject]@{Algorithm = "x16rt";      Fee = 2.5; MinMemGB = 2.0; Parameters = ""} #X16rt, new in 0.5.0
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --watchdog_script"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm ($_.Algorithm -replace "X16Rt", "X16RtGin"<#TempFix; Miner only supports Gin for X16Rt#>); $_} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {$_.Type -eq "CPU" -or ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("--algo=$($Algorithm) --api_listen=127.0.0.1:$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters --platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Xgminer"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $_.Fee / 100}
            }
        }
    }
}
