using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\z-enemy.exe"
$HashSHA256 = "8F6FA2209CA28E87E325049182AC9736BF84280A8203ADD34E21EABFF567526A"
$Uri = "https://github.com/z-enemy/z-enemy/releases/download/ver-2.3/z-enemy-2.3-win-cuda10.1.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA")

# Miner requires CUDA 10.1.00 or higher
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.1.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{ 
    "Aergo"      = " --algo=aergo" #Aergo, new in 1.11
    "Bitcore"    = " --algo=bitcore" #Timetravel10 and Bitcore are technically the same
    "Bcd"        = " --algo=bcd" #Bitcoin Diamond, new in 1.20
    "C11"        = " --algo=c11 --intensity=26" #C11, new in 1.11
    "Hex"        = " --algo=hex" #Hex
    "Phi"        = " --algo=phi" #PHI
    "Phi2"       = " --algo=phi2 --intensity=24" #Phi2
    #"Phi2-Lux"   = " --algo=phi2 --intensity=24" #Phi2-Lux, no reported hashrate withing reasonable time
    "Polytimos"  = " --algo=poly" #Polytimos
    "Skunk"      = " --algo=skunk" #Skunk, new in 1.11
    "Sonoa"      = " --algo=sonoa --intensity 26" #SONOA, new in 1.12
    "Timetravel" = " --algo=timetravel" #Timetravel
    "Tribus"     = " --algo=tribus" #Tribus, new in 1.10
    "X16r"       = " --algo=x16r --statsavg=50" #Raven, number of samples used to compute hashrate (default: 30) 
    "X16s"       = " --algo=x16s" #Pigeon
    "X16rv2"     = " --algo=x16rv2" #New with 2.2
    "X17"        = " --algo=x17" #X17
    "Xevan"      = " --algo=xevan --intensity=26" #Xevan, new in 1.09a
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Algorithm_Norm = @(@(Get-Algorithm ($_ -split '-' | Select-Object -First 1) | Select-Object) + @($_ -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host }| ForEach-Object { 
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) { 
            "C11"     { $WarmupTime = 90 }
            "Phi2"    { $WarmupTime = 60 }
            "Phi2Lux" { $WarmupTime = 60 }
            "Sonoa"   { $WarmupTime = 60 }
            "Xevan"   { $WarmupTime = 90 }
            "X16r"    { $WarmupTime = 60 }
            "X16rv2"  { $WarmupTime = 60 }
            default   { $WarmupTime = $Config.WarmupTime }
        }

        [PSCustomObject]@{ 
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands --api-bind=127.0.0.1:$($Miner_Port) --api-bind-http=0 --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$(if ($Pools.$Algorithm_Norm.SSL) {  " --no-cert-verify"  }) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass) --devices=$(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{ $Algorithm_Norm = 1 / 100 }
            WarmupTime = $WarmupTime #seconds
        }
    } 
}
