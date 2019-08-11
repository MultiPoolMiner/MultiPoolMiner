using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "F9A69BA3C00E80BBBE7054E8705FE07DC23B7C408FA5405B778441A24D1AD223"
$Uri = "https://github.com/djm34/ccminer-msvc2015/releases/download/v0.3.0/ccminer.rar"
$ManualUri = "https://github.com/djm34/ccminer-msvc2015"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    "blake2s"   = " -a blake2s" #Blake2s
    "blakecoin" = " -a blakecoin" #Blakecoin
    "c11"       = " -a c11" #C11
    "keccak"    = " -a keccak" #Keccak
    "lyra2h"    = " -a lyra2h" #Lyra2h
    #"lyra2v2"  = " -a lyra2v2" #Lyra2RE2 - Beaten by ccminerXevan by 80%
    "lyra2z"    = " -a lyra2z" #Lyra2z
    "neoscrypt" = " -a neoscrypt" #NeoScrypt
    "skein"     = " -a skein" #Skein
    "x11evo"    = " -a x11evo" #X11evo
    "x17"       = " -a x17" #X17
    
    # ASIC - never profitable 24/06/2018
    #"decred"    = " -a decred" #Decred
    #"groestl"   = " -a groestl" #Groestl
    #"lbry"      = " -a lbry" #Lbry
    #"myr-gr"    = " -a myr-gr" #MyriadGroestl
    #"nist5"     = " -a nist5" #Nist5
    #"qubit"     = " -a qubit" #Qubit
    #"quark"     = " -a quark" #Quark
    #"sib"       = " -a sib" #Sib
    #"x11"       = " -a x11" #X11
    #"x12"       = " -a x12" #X12
    #"x13"       = " -a x13" #X13
    #"x14"       = " -a x14" #X14
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

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
