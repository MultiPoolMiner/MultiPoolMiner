using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Alexis78hsr\ccminer.exe"
$HashSHA256 = "406E67B490F02F1FAAC8C4AA38B949832E8F93AC454B1BA6054ED04B83BAA31D"
$Uri = "https://github.com/nemosminer/ccminerAlexis78/releases/download/3%2F3%2F2018/ccminer-Alexis78.zip"

$Commands = [PSCustomObject]@{
    #GPU - profitable 13/05/2018
    #Intensities and parameters tested by nemosminer on 10603gb to 1080ti
    "c11"        = " -i 21" #X11evo; fix for default intensity
    "hsr"        = "" #HSR, HShare
    "keccak"     = " -m 2 -i 29" #Keccak; fix for default intensity, difficulty x M
    "lyra2"      = "" #Lyra2
    "lyra2v2"    = "" #lyra2v2
    "neoscrypt"  = "" #NeoScrypt
    "skein"      = "" #Skein
    "skein2"     = "" #skein2
    "veltor"     = " -i 23" #Veltor; fix for default intensity
    "whirlcoin"  = "" #WhirlCoin
    "whirlpool"  = "" #Whirlpool
    "whirlpoolx" = "" #whirlpoolx
    "x11evo"     = " -N 1 -i 21" #X11evo; fix for default intensity, N samples for hashrate
    "x17"        = " -i 20" #x17; fix for default intensity

    # ASIC - never profitable 13/05/2018
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
