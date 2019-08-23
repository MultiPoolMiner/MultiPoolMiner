using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$HashSHA256 = ""
$Uri = "https://github.com/cpu-pool/cpuminer-opt-cpupower/releases/download/v1.0/Cpuminer-opt-cpupower.zip"
$ManualUri = "https://github.com/JayDDee/cpuminer-opt"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = $Devices | Where-Object Type -EQ "CPU"

if ($Devices.CpuFeatures -match "sha2")     {$Miner_Path = ".\Bin\$($Name)\cpuminer-Avx2-Sha.exe"}
elseif ($Devices.CpuFeatures -match "avx2") {$Miner_Path = ".\Bin\$($Name)\cpuminer-Avx2.exe"}
elseif ($Devices.CpuFeatures -match "avx")  {$Miner_Path = ".\Bin\$($Name)\cpuminer-Avx.exe"}
elseif ($Devices.CpuFeatures -match "aes")  {$Miner_Path = ".\Bin\$($Name)\cpuminer-Aes-Sse42.exe"}
elseif ($Devices.CpuFeatures -match "sse2") {$Miner_Path = ".\Bin\$($Name)\cpuminer-Sse2.exe"}
else {$Miner_Path = ".\Bin\$($Name)\cpuminer.exe"}

$Commands = [PSCustomObject]@{
    "cpupower" = " -a cpupower" #CPUchain coin
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Devices | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name -replace "_", "$(($Miner_Path -split "\\" | Select-Object -Last 1) -replace "cpuminer" -replace ".exe" -replace "-")_") + @(($Devices.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '-') | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Devices.Name
            Path       = $Miner_Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            WarmupTime = 45 #seconds
        }
    }
}
