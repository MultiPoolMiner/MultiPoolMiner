using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "65DF5E551A82FBFF16173C1938B54147472ADE44664B0CACD44D6F597850B407"
$Uri = "https://github.com/Minerx117/ccminer/releases/download/8.21-r18-v5/ccmineryescryptrV5.zip"
$ManualUri = "https://github.com/tpruvot/ccminer"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA")

# Miner requires CUDA 10.1.00
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.1.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{ 
    "yescryptr8"     = " -a yescryptr8" #yescryptr8
    "yescryptr16"    = " -a yescryptr16 -i 13.2" #yescryptr16
    "yescryptr32"    = " -a yescryptr32 -i 12.22" #yescryptr32 
    "yescryptr8g"    = " -a yescrypt" #yescryptr8g
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " --submit-stale" }

$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { if ($_ -eq "monero") { $Algorithm_Norm = "cryptonight7" }<#TempFix, monero is no longer using cn7#> else  { $Algorithm_Norm = Get-Algorithm $_ }; $_ } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> } | ForEach-Object { 
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{ 
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
