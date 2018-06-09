﻿using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-KlausT\ccminer.exe"
$HashSHA256 = "EBF91E27F54DE29F158A4F5EBECEDB7E7E03EB9010331B2E949335BF1144A886"
$Uri = "https://github.com/KlausT/ccminer/releases/download/8.21/ccminer-821-cuda91-x64.zip"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "c11"         = "" #C11
    "deep"        = "" #deep
    "dmd-gr"      = "" #dmd-gr
    "fresh"       = "" #fresh
    "fugue256"    = "" #Fugue256
    "groestl"     = "" #Groestl
    "jackpot"     = "" #Jackpot
    "keccak"      = "" #Keccak
    "luffa"       = "" #Luffa
    "lyra2v2"     = "" #Lyra2RE2
    "neoscrypt"   = "" #NeoScrypt
    "penta"       = "" #Pentablake
    "skein"       = "" #Skein
    "s3"          = "" #S3
    "veltor"      = "" #Veltor
    #"whirlpool"  = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    "X17"         = "" #X17 Verge

    # ASIC - never profitable 20/04/2018
    #"blake"      = "" #blake
    #"blakecoin"  = "" #Blakecoin
    #"blake2s"    = "" #Blake2s
    #"myr-gr"     = "" #MyriadGroestl
    #"nist5"      = "" #Nist5
    #"quark"      = "" #Quark
    #"qubit"      = "" #Qubit
    #"vanilla"    = "" #BlakeVanilla
    #"sha256d"    = "" #sha256d
    #"sia"        = "" #SiaCoin
    #"x11"        = "" #X11
    #"x13"        = "" #x13
    #"x14"        = "" #x14
    #"x15"        = "" #x15
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "NVIDIA"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "-a $_ -b 4068 -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Ccminer"
        Port       = 4068
        URI        = $Uri
    }
}
