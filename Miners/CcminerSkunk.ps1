﻿using module ..\Include.psm1

$Path = ".\Bin\Skunk-NVIDIA\ccminer.exe"
$HashSHA256 = "B0517639B174E2A7776A5567F566E1C0905A7FE439049D33D44A7502DE581F7B"
$URI = "https://github.com/scaras/ccminer-2.2-mod-r1/releases/download/2.2-r1/2.2-mod-r1.zip"

$Commands = [PSCustomObject]@{
    "blake2s"   = "" #Blake2s
    "blakecoin" = "" #Blakecoin
    "c11"       = "" #C11
    "groestl"   = "" #Groestl
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
    
    # ASIC - never profitable 12/05/2018
    #"decred"   = "" #Decred
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

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
    }
}
