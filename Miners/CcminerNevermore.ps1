using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Nevermore\ccminer.exe"
$HashSHA256 = "940EB4C246019216C8F95FFB2F2E65FA147B13A65756A38D660146672E47844B"
$Uri = "https://github.com/nemosminer/ccminerx16r-x16s/releases/download/v0.5/ccminerx16rx16s64-bit.7z"

$Commands = [PSCustomObject]@{
    "bitcore" = "" #Bitcore
    "c11" = "" #C11
    #"equihash" = "" #Equihash - Beaten by Bminer by 30%
    "groestl" = "" #Groestl
    "hmq1725" = "" #HMQ1725
    "hsr" = "" #HSR
    "jha" = "" #JHA - NOT TESTED
    "keccak" = "" #Keccak
    "keccakc" = "" #Keccakc
    "lyra2v2" = "" #Lyra2RE2
    "lyra2z" = "" #Lyra2z
    "neoscrypt" = "" #NeoScrypt
    "phi" = "" #PHI
    "poly" = "" #Polytmos - NOT TESTED
    "skein" = "" #Skein
    "skunk" = "" #Skunk
    "timetravel" = "" #Timetravel
    "tribus" = "" #Tribus
    "veltor" = "" #Veltor - NOT TESTED
    "x11evo" = "" #X11evo
    "x12" = "" #X12 - NOT TESTED
    "x16r" = "" #Raven
    "x16s" = "" #Pigeon
    "x17" = "" #X17
   
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
    
    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        HashSHA256 = $HashSHA256
        Arguments = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
        PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
    }
}
