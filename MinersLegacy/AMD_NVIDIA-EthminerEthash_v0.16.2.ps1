using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ethminer.exe"
$HashSHA256 = "9118230AA0D1166979A7146EC0CC4D0A41B29CB45C3A3805AA03A13C1BD87D2C"
$Uri = "https://github.com/ethereum-mining/ethminer/releases/download/v0.16.2/ethminer-0.16.2-windows-amd64.zip"
$ManualUri = "https://github.com/ethereum-mining/ethminer"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "ethash2gb"; MinMemGB = 2; Params = ""} #Ethash2GB
    [PSCustomObject]@{Algorithm = "ethash3gb"; MinMemGB = 3; Params = ""} #Ethash3GB
    [PSCustomObject]@{Algorithm = "ethash"   ; MinMemGB = 4; Params = ""} #Ethash
)
$CommonCommands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {$Arguments_Platform = " --opencl --opencl-devices "}
        "NVIDIA Corporation" {$Arguments_Platform = " --cuda --cuda-devices "}
        Default {$Arguments_Platform = ""}
    }

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            }
            $Miner_Name = $Miner_Name -replace "[-]{2,}", "-"

            #Get commands for active miner devices
            $Params = Get-CommandPerDevice $_.Params $Miner_Device.Type_Vendor_Index

            #Stratum autodetection
            if ($Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp") {$Protocol = "stratum://"} else {$Protocol = "stratums://"}
            
            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("--api-port -$Miner_Port -P $($Protocol)$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$Params$CommonCommands$Arguments_Platform$(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Claymore"
                Port       = $Miner_Port
                URI        = $Uri
            }
        }
    }
}
