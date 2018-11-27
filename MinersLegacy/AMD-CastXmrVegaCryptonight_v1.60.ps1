using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\cast_xmr-vega.exe"
$HashSHA256 = "6EA3D830E3CBAA7CE4DFD84CE10B90A517803132ED86B24D8591F17039688F86"
$Uri = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_160.zip"
$ManualUri = "http://www.gandalph3000.com"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm_Norm = "CryptonightV7";        AlgoNumber =  1; MinMemGB = 2; Params = ""} #CryptonightV7
    [PSCustomObject]@{Algorithm_Norm = "CryptonightHeavy";     AlgoNumber =  2; MinMemGB = 4; Params = ""} #CryptonightHeavy
    [PSCustomObject]@{Algorithm_Norm = "CryptonightLite";      AlgoNumber =  3; MinMemGB = 1; Params = ""} #CryptonightLite
    [PSCustomObject]@{Algorithm_Norm = "CryptonightLiteV7";    AlgoNumber =  4; MinMemGB = 1; Params = ""} #CryptonightLiteV7
    [PSCustomObject]@{Algorithm_Norm = "CryptonightHeavyTube"; AlgoNumber =  5; MinMemGB = 4; Params = ""} #CryptonightHeavyTube
    [PSCustomObject]@{Algorithm_Norm = "CryptonightXtl";       AlgoNumber =  6; MinMemGB = 2; Params = ""} #CryptonightXtl
    [PSCustomObject]@{Algorithm_Norm = "CryptonightHeavyXhv";  AlgoNumber =  7; MinMemGB = 4; Params = ""} #CryptonightHeavyXhv
    [PSCustomObject]@{Algorithm_Norm = "CryptonightFast";      AlgoNumber =  8; MinMemGB = 2; Params = ""} #CryptonightFast
    [PSCustomObject]@{Algorithm_Norm = "CryptonightRto";      AlgoNumber =  9; MinMemGB = 2; Params = ""} #CryptonightFest (not to be confused with CryptonightFast), new with 1.50
    [PSCustomObject]@{Algorithm_Norm = "CryptonightV8";        AlgoNumber = 10; MinMemGB = 2; Params = ""} #CryptonightV8, new with 1.50

    # ASIC only (09/07/2018)
    #[PSCustomObject]@{Algorithm_Norm = "Cryptonight";          AlgoNumber = 0; MinMemGB = 2; Commands = ""} #Cryptonight
)
$CommonCommands = " --fastjobswitch --intensity -1"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | ForEach-Object {
        $Algorithm_Norm = $_.Algorithm_Norm
        $Params = $_.Params
        $MinMemGB = $_.MinMemGB

        $Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB -and $_.OpenCL.Name -match "^Ellesmere.*|^Polaris.*|^Vega.*|^gfx900.*"})

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Device.Name | Sort-Object) | Select-Object) -join '-'
            }

            #Get commands for active miner devices
            $Params = Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("--remoteaccess --remoteport $($Miner_Port) -a $($_.AlgoNumber) -S $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --opencl $($Miner_Device | Select-Object -First 1 -ExpandProperty PlatformId) $(if ($Pools.$Algorithm_Norm.Name -ne "NiceHash") {" --nonicehash"}) -G $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')$Params$CommonCommands" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Cast"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 1.5 / 100}
            }
        }
    }
}
