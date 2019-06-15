﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "B0517639B174E2A7776A5567F566E1C0905A7FE439049D33D44A7502DE581F7B"
$Uri = "https://github.com/scaras/ccminer-2.2-mod-r1/releases/download/2.2-r1/2.2-mod-r1.zip"
$ManualUri = "https://github.com/scaras/ccminer-2.2-mod-r1"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        "blake2s"   = "" #Blake2s
        "blakecoin" = "" #Blakecoin
        "c11"       = "" #C11
        "hmq1725"   = "" #HMQ1725
        "lyra2v2"   = "" #Lyra2RE2
        "lyra2z"    = "" #Lyra2z
        "neoscrypt" = "" #NeoScrypt
        "skein"     = "" #Skein
        "skunk"     = "" #Skunk
        "timetravel"= "" #Timetravel
        "tribus"    = "" #Tribus
        "x11evo"    = "" #X11evo
        "x17"       = "" #X17
        
        # ASIC - never profitable 24/06/2018
        #"decred"   = "" #Decred
        #"groestl"  = "" #Groestl
        #"lbry"     = "" #Lbry
        #"myr-gr"   = "" #MyriadGroestl
        #"nist5"    = "" #Nist5
        #"qubit"    = "" #qubit
        #"quark"    = "" #Quark
        #"sib"      = "" #Sib
        #"x11"      = "" #X11
        #"x12"      = "" #X12
        #"x13"      = "" #X13
        #"x14"      = "" #X14
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1
        
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

        #Get parameters for active miner devices
        if ($Miner_Config.Parameters.$Algorithm_Norm) {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
        }
        elseif ($Miner_Config.Parameters."*") {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
        }
        else {
            $Parameters = Get-ParameterPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
