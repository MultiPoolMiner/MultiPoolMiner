using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\NeoScryptMiner.exe"
$HashSHA256 = "AF7E52C6F71B2B114299BB2AFAAF11B65800AC0390C037473E0CEBAE8E9D4BC5"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/neoscryptminer/Claymore.s.NeoScrypt.AMD.GPU.Miner.v1.2.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3012600.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    "neoscrypt" = "" #NeoScrypt
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

##CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " -r -1 -a 2 -dbg -1"} #turn off all logs

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -DeviceIDs $Miner_Device.Type_Vendor_Index

        if ($Pools.$Algorithm_Norm.SSL) {$Miner_Fee = 2.5}
        else {$Miner_Fee = 2}

        #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) {$Miner_Config = [PSCustomObject]@{DisableDevFeeMining = $Config.DisableDevFeeMining}}
        if ($Miner_Config.DisableDevFeeMining) {
            $NoFee = " -nofee 1"
            $Miner_Fee = 0
        }
        else {$NoFee = ""}

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -mport -$Miner_Port -pool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -psw $($Pools.$Algorithm_Norm.Pass) -di $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Slot)}) -join '')$NoFee" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Claymore"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{$Algorithm_Norm = $Miner_Fee / 100}
        }
    }
}
