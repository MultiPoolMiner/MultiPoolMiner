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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "CryptonightV7";        AlgoNumber =  1; MinMemGB = 2; Params = ""} #CryptonightV7
        [PSCustomObject]@{Algorithm = "CryptonightHeavy";     AlgoNumber =  2; MinMemGB = 4; Params = ""} #CryptonightHeavy
        [PSCustomObject]@{Algorithm = "CryptonightLite";      AlgoNumber =  3; MinMemGB = 1; Params = ""} #CryptonightLite
        [PSCustomObject]@{Algorithm = "CryptonightLiteV7";    AlgoNumber =  4; MinMemGB = 1; Params = ""} #CryptonightLiteV7
        [PSCustomObject]@{Algorithm = "CryptonightHeavyTube"; AlgoNumber =  5; MinMemGB = 4; Params = ""} #CryptonightHeavyTube
        [PSCustomObject]@{Algorithm = "CryptonightXtl";       AlgoNumber =  6; MinMemGB = 2; Params = ""} #CryptonightXtl
        [PSCustomObject]@{Algorithm = "CryptonightHeavyXhv";  AlgoNumber =  7; MinMemGB = 4; Params = ""} #CryptonightHeavyXhv
        [PSCustomObject]@{Algorithm = "CryptonightFast";      AlgoNumber =  8; MinMemGB = 2; Params = ""} #CryptonightFast
        [PSCustomObject]@{Algorithm = "CryptonightRto";       AlgoNumber =  9; MinMemGB = 2; Params = ""} #CryptonightFest (not to be confused with CryptonightFast), new with 1.50
        [PSCustomObject]@{Algorithm = "CryptonightV8";        AlgoNumber = 10; MinMemGB = 2; Params = ""} #CryptonightV8, new with 1.50
        [PSCustomObject]@{Algorithm = "CryptonightXfh";       AlgoNumber = 11; MinMemGB = 2; Params = ""} #CryptoNightXfh, new with 1.65

        # ASIC only (09/07/2018)
        #[PSCustomObject]@{Algorithm_Norm = "Cryptonight";          AlgoNumber = 0; MinMemGB = 2; Commands = ""} #Cryptonight
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --fastjobswitch --intensity -1"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp"} | ForEach-Object {
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB -and $_.Model_Norm -match "^Baffin.*|^Ellesmere.*|^Polaris.*|^Vega.*|^gfx900.*"})) {
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
                Arguments  = ("--remoteaccess --remoteport $($Miner_Port) -a $($_.AlgoNumber) -S $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --opencl $($Miner_Device | Select-Object -First 1 -ExpandProperty PlatformId) $(if ($Pools.$Algorithm_Norm.Name -ne "NiceHash") {" --nonicehash"}) -G $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')$Parameters$CommonParameters" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Cast"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 1.5 / 100}
            }
        }
    }
}
