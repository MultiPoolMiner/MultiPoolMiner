﻿. .\Include.ps1

$Path = ".\Bin\CPU-JayDDee\cpuminer-aes-sse42.exe"
$Uri = "https://github.com/JayDDee/cpuminer-opt/releases/download/v3.6.3/cpuminer-opt-3.6.3-windows.zip"

$Commands = [PSCustomObject]@{
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"vanilla" = "" #BlakeVanilla
    #"c11" = "" #C11
    "cryptonight" = "" #CryptoNight
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = "" #Groestl
    "hmq1725" = "" #HMQ1725
    #"jha" = "" #JHA
    #"keccak" = "" #Keccak
    #"lbry" = "" #Lbry
    #"lyra2v2" = "" #Lyra2RE2
    "lyra2z" = "" #Lyra2z
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = "" #NeoScrypt
    #"nist5" = "" #Nist5
    #"pascal" = "" #Pascal
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sia" = "" #Sia
    #"sib" = "" #Sib
    #"skein" = "" #Skein
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"veltor" = "" #Veltor
    #"x11" = "" #X11
    #"x11evo" = "" #X11evo
    #"x17" = "" #X17
    #"yescrypt" = "" #Yescrypt
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{
        Type = "CPU"
        Path = $Path
        Arguments = "-a $_ -o stratum+tcp://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --max-temp=$($Temp_CPU) -R 5 "
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4048
        Wrap = $false
        URI = $Uri
    }
}
