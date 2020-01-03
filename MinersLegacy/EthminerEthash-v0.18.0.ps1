using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ethminer.exe"
$HashSHA256 = "B783C74E53A5FCDF7D798D268E1ABF6F30235B792E041C9972AB844E015B1984"
$Uri = "https://github.com/ethereum-mining/ethminer/releases/download/v0.18.0/ethminer-0.18.0-cuda10.0-windows-amd64.zip"
$ManualUri = "https://github.com/ethereum-mining/ethminer"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "ethash2gb"; MinMemGB = 2; Command = "" } #Ethash2GB
    [PSCustomObject]@{ Algorithm = "ethash3gb"; MinMemGB = 3; Command = "" } #Ethash3GB
    [PSCustomObject]@{ Algorithm = "ethash"   ; MinMemGB = 4; Command = "" } #Ethash
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices = @($Devices | Where-Object Type -EQ "GPU")
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    switch ($_.Vendor) { 
        "AMD" { $Arguments_Platform = " --opencl --opencl-devices " }
        "NVIDIA" { $Arguments_Platform = " --cuda --cuda-devices " }
        Default { $Arguments_Platform = "" }
    }

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            $Protocol = "stratum$(if ($Pools.$Algorithm_Norm.Name -like "NiceHash*") { "2" })$(if ($Pools.$Algorithm_Norm.SSL) { "+ssl" } else { "+tcp" })://"
            
            [PSCustomObject]@{ 
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands --api-port -$Miner_Port -P $($Protocol)$(if ($Pools.$Algorithm_Norm.Name -like "MiningPoolHub*") { $($Pools.$Algorithm_Norm.User -replace "\.", "%2e") } else { $($Pools.$Algorithm_Norm.User) }):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$Arguments_Platform$(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ' ')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                API        = "Claymore"
                Port       = $Miner_Port
                URI        = $Uri
            }
        }
    }
}
