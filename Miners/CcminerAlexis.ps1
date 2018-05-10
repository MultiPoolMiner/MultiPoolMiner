using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Alexis78hsr\ccminer-alexis.exe"
$Uri = "https://github.com/nemosminer/ccminer-hcash/releases/download/alexishsr/ccminer-hsr-alexis-x86-cuda8.7z"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "blake2s" = "" #Blake2s
    "c11" = "" #c11
    "hsr" = "" #HSR, HShare
    "keccak" = "" #Keccak
    "lyra2" = "" #Lyra2
    "lyra2v2" = "" #lyra2v2
    #"neoscrypt" = "" #NeoScrypt
    #"skein" = "" #Skein
    "skein2" = "" #skein2
    "veltor" = "" #Veltor
    #"whirlcoin" = "" #WhirlCoin
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    "x11evo" = "" #X11evo
    "x17" = "" #x17

    # ASIC - never profitable 20/04/2018
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"cryptolight" = "" #cryptolight
    #"cryptonight" = "" #CryptoNight
    #"decred" = "" #Decred
    #"lbry" = "" #Lbry
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"scrypt:N" = "" #scrypt:N
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"sib" = "" #Sib
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
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}
