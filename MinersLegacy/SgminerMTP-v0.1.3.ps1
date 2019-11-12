using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\sgminer.exe"
$HashSHA256 = "CBE3F0349E28E7844257E91FB5A93D138B0BD78277D57224ED8ED61D5B8D30D5"
$Uri = "https://github.com/zcoinofficial/sgminer/releases/download/0.1.3/sgminer.zip"
$ManualUri = "https://github.com/zcoinofficial/sgminer"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) { $Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*" }

$Commands = [PSCustomObject]@{ 
    "mtp" = " --kernel mtp --intensity 18 -p 0,strict,verbose,d=700" #MTP
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "$(if (-not $Config.ShowMinerWindow) { ' --text-only' })" }

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD" | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge 4 })
$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_; $_ } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" -and $Pools.$Algorithm_Norm.Name -ne "NiceHash"<#temp fix#> } | ForEach-Object { 
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("algorithm", "k", "kernel") -DeviceIDs $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{ 
            Name              = $Miner_Name
            BaseName          = $Miner_BaseName
            Version           = $Miner_Version
            DeviceName        = $Miner_Device.Name
            Path              = $Path
            HashSHA256        = $HashSHA256
            Arguments         = ("$Command$CommonCommands --api-listen --api-port $Miner_Port --url $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) --gpu-platform $($Miner_Device.PlatformId | Sort-Object -Unique) --device $(($Miner_Device | ForEach-Object { '{0:x}' -f $_.Type_Vendor_Index }) -join ',')" -replace "\s+", " ").trim()
            HashRates         = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API               = "Xgminer"
            Port              = $Miner_Port
            URI               = $Uri
            BenchmarkInterval = 2
            WarmupTime        = 90 #seconds
        }
    }
}
