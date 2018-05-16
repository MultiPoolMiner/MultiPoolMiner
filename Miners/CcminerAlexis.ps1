using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Alexis78hsr\ccminer.exe"
$HashSHA256 = "B0222106230616A31A93811640E8488BDCDA0FBF9EE2C5AD7EB1B3F4E4421884"
$Uri = "https://github.com/nemosminer/ccminerAlexis78/releases/download/Alexis78-v1.2/ccminerAlexis78v1.2x32.7z"

$Commands = [PSCustomObject]@{
    #GPU - profitable 16/05/2018
    #Intensities and parameters tested by nemosminer on 10603gb to 1080ti
    "c11"        = " -i 21" #X11evo; fix for default intensity
    "hsr"        = "" #HSR, HShare
    "keccak"     = " -m 2 -i 29" #Keccak; fix for default intensity, difficulty x M
    "keccakc"    = " -i 29" #Keccakc; fix for default intensity
    "lyra2"      = "" #Lyra2
    "lyra2v2"    = "" #lyra2v2
    "neoscrypt"  = "" #NeoScrypt
    "poly"       = "" #Poly
    "skein"      = "" #Skein
    "skein2"     = "" #skein2
    "veltor"     = " -i 23" #Veltor; fix for default intensity
    "whirlcoin"  = "" #WhirlCoin
    "whirlpool"  = "" #Whirlpool
    "whirlpoolx" = "" #whirlpoolx
    "x11evo"     = " -N 1 -i 21" #X11evo; fix for default intensity, N samples for hashrate
    "x17"        = " -i 20" #x17; fix for default intensity

    # ASIC - never profitable 16/05/2018
    #"blake2s" = "" #Blake2s
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
