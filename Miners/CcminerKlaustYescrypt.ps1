using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-KlausT\ccminer.exe"
$Uri = "https://github.com/KlausT/ccminer/releases/download/8.21/ccminer-821-cuda91-x64.zip"

$Commands = [PSCustomObject]@{
    #GPU - profitable 27/03/2018
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"c11" = "" #C11
    #"deep" = "" #deep
    #"dmd-gr" = "" #dmd-gr
    #"doom" = "" #Doom
    #"fresh" = "" #fresh
    #"fugue256" = "" #Fugue256
    #"groestl" = "" #Groestl
    #"keccak" = "" #Keccak
    #"jackpot" = "" #Jackpot
    #"luffa" = "" #Luffa
    #"lyra2v2" = "" #Lyra2RE2
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = "" #NeoScrypt
    #"#nist5" = "" #Nist5
    #"pentablake" = "" #pentablake
    #"penta" = "" #Pentablake
    #"skein" = "" #Skein
    #"s3" = "" #S3
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"vanilla" = "" #BlakeVanilla
    #"veltor" = "" #Veltor
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    #"x17" = "" #x17
    "yescryptR8" = ""
    "yescryptR16" = "" #YescryptR16 #Yenten
    "yescryptR16v2" = "" #PPNP
    "yescryptR32" = "" #WAVI

    # ASIC - never profitable 27/03/2018
    #"blake2s" = "" #Blake2s
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"x11" = "" #X11
    #"x13" = "" #x13
    #"x14" = "" #x14
    #"x15" = "" #x15
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -b 4068 -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}
