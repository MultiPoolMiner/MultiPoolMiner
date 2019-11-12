using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "998AEBAA80CD6D2B758A5B4798D6AC929745B88D81735587798F616D7E2F3B23"
$Uri = "https://github.com/nicehash/ccminer-nanashi/releases/download/1.7.6-r6/ccminer.zip"
$ManualUri = "https://github.com/nicehash/ccminer-nanashi"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    #"blake2s"  = " -a blake2s" #Blake2s - Beaten by ccminerSib by 150%
    "blakecoin" = " -a blakecoin" #Blakecoin
    "c11"       = " -a c11" #C11
    "keccak"    = " -a keccak" #Keccak
    "lyra2v2"   = " -a lyra2v2" #Lyra2RE2
    "neoscrypt" = " -a neoscrypt" #NeoScrypt
    "skein"     = " -a skein" #Skein
    "x17"       = " -a x17" #X17
    
    # ASIC - never profitable 24/06/2018
    #"decred"   = " -a decred" #Decred
    #"groestl"  = " -a groestl" #Groestl
    #"myr-gr"   = " -a myr-gr" #MyriadGroestl
    #"nist5"    = " -a nist5" #Nist5
    #"qubit"    = " -a qubit" #qubit
    #"quark"    = " -a quark" #Quark
    #"sib"      = " -a sib" #Sib
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "C11"   {$WarmupTime = 60}
            default {$WarmupTime = 30}
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            WarmupTime = $WarmupTime
        }
    }
}
