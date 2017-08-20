. .\Include.ps1

$Path = ".\Bin\ccminer-2-2-mod-r1\ccminer.exe"
$URI = "https://github.com/scaras/ccminer-2.2-mod-r1/releases/download/2.2-r1/2.2-mod-r1.zip"

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands = [PSCustomObject]@{

    "anime" = ""
    "bastion" = ""

    "bitcore" = "" 
    #"blake" = ""
    "blakecoin" = ""
    "blake2s" = "" 
    "bmw" = ""
    "c11" = "" 
    #"cryptolight" = ""
    #"cryptonight" = ""  
   # "decred" = "" 
    "deep" = ""
    "dmd-gr" = "" 
    "fresh" = ""
    "fugue256" = ""
    "groestl" = "" 
    "heavy" = "" 
    #"hmq1725" = ""
    "jha" = "" 
    "keccak" = "" 
    "lbry" = "" 
    "luffa" = ""
    "lyra2" = "" 
    "lyra2v2" = "" 
    "lyra2z" = "" 
    "mjollnir" = "" 
    "myr-gr" = "" 
    "neoscrypt" = ""
    "nist5" = "" 
    #"pascal" = "" 
    "penta" = ""
    "quark" = ""  
    "qubit" = "" 
    "s3" = "" 
    "scrypt" = "" 
    #"sia" = ""  
    "sib" = ""
    "skein" = "" 
    "skein2" = ""
    "skunk" = ""
    "timetravel" = "" 
    "tribus" = "" 
    "vanilla" = "" 
    "veltor" = "" 
    "whirlpool" = ""
    #"whirlpoolx" = ""
    "wildkeccak" = ""
    "x11" = "" 
    "x11evo" = "" 
    #"x11gost" = ""
    "x13" = "" 
    "x14" = ""
    "x15" = "" 
    "x17" = "" 
    #"xevan" = "" 
    #"yescrypt" = "" 
    "zr5" = ""
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = " -R 5 --max-temp=70 -a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}