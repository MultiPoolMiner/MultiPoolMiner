﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\zjazz_amd.exe"
$HashSHA256 = "D35269E9EBF51DEA8AFFF2C3AFDC1633518D1A4689FA2CC6CA30425E1935E218"
$Uri = "https://github.com/zjazz/zjazz_amd_miner/releases/download/v0.92/zjazz_amd_win64_092.zip"
$ManualURI = "https://github.com/zjazz/zjazz_amd_miner"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "phi2" = "" #Phi2
}
$CommonCommmands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc." | Where-Object {$_.OpenCL.GlobalMemsize -ge 2GB} | Where-Object OpenCL.Name -match "^Ellesmere.*|^Polaris.*|^Vega.*")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = <#temp fix#> Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index
        
        [PSCustomObject]@{
            Name           = $Miner_Name
            DeviceName     = $Miner_Device.Name
            Path           = $Path
            HashSHA256     = $HashSHA256
            Arguments      = ("-a phi2 -o $($Pools.PHI2.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
            HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API            = "Wrapper"
            Port           = $Miner_Port
            URI            = $Uri
            Fees           = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
        }
    }
}
