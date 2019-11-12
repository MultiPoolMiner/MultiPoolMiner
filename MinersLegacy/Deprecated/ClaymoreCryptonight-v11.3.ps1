using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\NsGpuCNMiner.exe"
$HashSHA256 = "2EF61DC0157469315831CD6486711617DB80B819AB9E10DB9FDD9D66D95D3F28"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/claymorecryptonoteamd/Claymore.CryptoNote.AMD.GPU.Miner.v11.3.-.POOL.-.Catalyst.15.12-18.x.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=638915.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    "cryptonightV7"   = " -pow7 1" #CryptoNightV7
    "cryptonightLite" = " -lite 1" #CryptoNightLite
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " -r -1"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -DeviceIDs $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -mport -$Miner_Port -xpool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -xwal $($Pools.$Algorithm_Norm.User) -xpsw $($Pools.$Algorithm_Norm.Pass) -di $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Slot}) -join '')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Claymore"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
