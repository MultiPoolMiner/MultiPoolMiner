using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Nevermore\ccminer.exe"
$HashSHA256 = "6148f640e011395df00a59bb0d01af194cee32c729f493c491163de8d695f170"
$Uri = "https://github.com/nemosminer/ccminerx16r-x16s/releases/download/x16rx16sv0.4/ccminerx16rx16sv0.4.zip"

$Commands = [PSCustomObject]@{
    #"bitcore" = "" #Bitcore - Beaten by ccminerZealot
    "c11" = "" #C11
    #"cryptonight" = "" #CryptoNight
    #"equihash" = "" #Equihash - Beaten by Bminer
    #"ethash" = "" #Ethash - Not Supported
    #"groestl" = "" #Groestl - Beaten by ccminerKlaust
    "hmq1725" = "" #HMQ1725
    #"hsr" = "" #HSR - Beaten by PalginNvidia
    "jha" = "" #JHA - NOT TESTED
    #"keccak" = "" #Keccak - Beaten by ccminerPolytimos
    "keccakc" = "" #Keccakc
    #"lyra2v2" = "" #Lyra2RE2 - Beaten by ccminerXevan
    #"lyra2z" = "" #Lyra2z - Beaten by ccminerTpruvot
    #"neoscrypt" = "" #NeoScrypt - Beaten by PalginNvidia
    #"pascal" = "" #Pascal - Not Supported
    "phi" = "" #PHI
    "poly" = "" #Polytmos
    #"skein" = "" #Skein - Beaten by ccminerHsr
    "skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel - Beaten by ccminerRaven
    "tribus" = "" #Tribus
    "veltor" = "" #Veltor - NOT TESTED
    #"x11evo" = "" #X11evo - Beaten by ccminerSib
    "x12" = "" #X12 - NOT TESTED
    "x16r" = "" #Rave
    "x16s" = "" #Pigeon
    #"x17" = "" #X17 - Beaten by ccminerEnemy
    #"yescrypt" = "" #Yescrypt - Not Supported
    #"xevan" = "" #Xevan - Not Supported
   
    # ASIC - never profitable 11/05/2018
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"blake2s" = "" #Blake2s
    #"decred" = "" #Decred
    #"decrednicehash" = "" #Decrednicehash 
    #"lbry" = "" #Lbry
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"sib" = "" #Sib
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
        HashSHA256 = $HashSHA256
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
        PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
    }
}
