using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\sgminer.exe"
$HashSHA256 = "F20223113CF9A2A65ED3C787006FD09CC750243682537C86BACB5BDC563B6DDF"
$Uri = "https://github.com/LIMXTEC/Xevan-GPU-Miner/releases/download/1/sgminer-xevan-5.5.0-nicehash-1-windows-amd64.zip"
$ManualUri = "https://github.com/LIMXTEC/Xevan-GPU-Miner"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    "xevan-mod" = " --kernel xevan-mod --intensity 15" #Xevan
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " $(if (-not $Config.ShowMinerWindow) {' --text-only'})"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("algorithm", "k", "kernel") -DeviceIDs $Miner_Device.Type_Vendor_Index

        #Allow time to build binaries
        if (-not (Get-Stat "$($Miner_Name)_$($Algorithm_Norm)_HashRate")) {$WarmupTime = 90} else {$WarmupTime = 30}

        [PSCustomObject]@{
            Name        = $Miner_Name
            BaseName    = $Miner_BaseName
            Version     = $Miner_Version
            DeviceName  = $Miner_Device.Name
            Path        = $Path
            HashSHA256  = $HashSHA256
            Arguments   = ("$Command$CommonCommands --api-listen --api-port $Miner_Port --url $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) --gpu-platform $($Miner_Device.PlatformId | Sort-Object -Unique) --device $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API         = "Xgminer"
            Port        = $Miner_Port
            URI         = $Uri
            Environment = @("GPU_FORCE_64BIT_PTR=0")
            WarmupTime  = $WarmupTime #seconds
        }
    }
}
