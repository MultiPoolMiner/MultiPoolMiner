﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "32E36BD667A3CCF49C3394C40E2FF15DE0ADDBA8E25C093F952E26157854FDC4"
$Uri = "https://github.com/ocminer/suprminer/releases/download/2.0/suprminer-2.0.7z"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "bitcore"   = "" #Bitcore
    "blake2s"   = "" #Blake2s
    "blakecoin" = "" #Blakecoin
    "c11"       = "" #C11
    "hmq1725"   = "" #HMQ1725
    "hsr"       = "" #HSR
    "keccak"    = "" #Keccak
    "keccakc"   = "" #Keccakc
    "lyra2v2"   = "" #Lyra2RE2
    "lyra2z"    = "" #Lyra2z
    "neoscrypt" = "" #NeoScrypt
    "phi"       = "" #PHI
    "skein"     = "" #Skein
    "skunk"     = "" #Skunk
    "timetravel"= "" #Timetravel
    "tribus"    = "" #Tribus
    "x11evo"    = "" #X11evo
    "x16r"      = "" #X16R
    "x16rt"     = "" #X16Rt
    "x16s"      = "" #X16S
    "x17"       = "" #X17
    
    # ASIC - never profitable 24/06/2018
    #"decred"   = "" #Decred
    #"groestl"  = "" #Groestl
    #"lbry"     = "" #Lbry
    #"myr-gr"   = "" #MyriadGroestl
    #"nist5"    = "" #Nist5
    #"qubit"    = "" #Qubit
    #"quark"    = "" #Quark
    #"sib"      = "" #Sib
    #"x11"      = "" #X11
    #"x12"      = "" #X12
    #"x13"      = "" #X13
    #"x14"      = "" #X14
}
$CommonCommands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = <#temp fix#> Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "X16R"  {$BenchmarkIntervals = 5}
            default {$BenchmarkIntervals = 1}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Ccminer"
            Port               = $Miner_port
            URI                = $Uri
            BenchmarkIntervals = $BenchmarkIntervals
        }
    }
}
