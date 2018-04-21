using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-SP\ccminer.exe"
$Uri = "https://github.com/sp-hash/ccminer/releases/download/1.5.81/release81.7z"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "bastion" = "" #bastion
    "c11" = "" #C11
    "deep" = "" #deep
    "dmd-gr" = "" #dmd-gr
    "doom" = "" #Doom
    "fresh" = "" #fresh
    "fugue256" = "" #Fugue256
    "groestl" = "" #Groestl
    "heavy" = "" #heavy
    "keccak" = "" #Keccak
    "jackpot" = "" #JackPot
    "luffa" = "" #Luffa
    "lyra2" = "" #lyra2h
    #"lyra2v2" = "" #Lyra2RE2
    "mjollnir" = "" #Mjollnir
    "neoscrypt" = "" #NeoScrypt
    "pentablake" = "" #pentablake
    "phi" = "" #PHI
    "scryptjane:nf" = "" #scryptjane:nf
    #"skein" = "" #Skein
    "s3" = "" #S3
    "spreadx11" = "" #Spread
    #"whirl" = "" #Whirlpool
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    "x17" = "" #x17
    "yescrypt" = "" #Yescrypt

    # ASIC - never profitable 27/03/2018
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"blake2s" = "" #Blake2s
    #"decred" = "" #Decred
    #"lbry" = "" #Lbry
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"scrypt:N" = "" #scrypt:N
    #"sha256d" = "" #sha256d Bitcoin
    #"sia" = "" #SiaCoin
    #"vanilla" = "" #BlakeVanilla
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
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass) -b 4068$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}
