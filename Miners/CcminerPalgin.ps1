. .\Include.ps1

$Path = ".\Bin\NVIDIA-Palgin\ccminer.exe"
$Uri = "https://github.com/palginpav/ccminer/releases/download/1.1.1/palginmod_1.1_x86.zip"

$Commands = [PSCustomObject]@{
    "bastion" = ""

    #"bitcore" = "" 
    "blake" = ""
    "blake2s" = "" 
    #"blakecoin" = "" 
    "bmw" = ""
    "c11" = "" 
    #"cryptolight" = ""
    #"cryptonight" = ""  
   ##"decred" = "" 
    "deep" = ""
    "dmd-gr" = "" 
    #"equihash" = "" 
    "fresh" = ""
    "fugue256" = ""
    "groestl" = "" 
    "heavy" = "" 
    #"hmq1725" = "" 
    "jackpot" = "" 
    #"jha" = ""
    "keccak" = "" 
    "lbry" = "" 
    "luffa" = ""
    "lyra2" = ""
    "lyra2v2" = "" 
    #"lyra2z" = "" 
    #"m7m" = "" 
    "mjollnir" = "" 
    "myr-gr" = "" 
    #"neoscrypt" = "" 
    "nist5" = "" 
   ##"pascal" = "" 
    "penta" = ""
    "quark" = "" 
    "qubit" = "" 
    "s3" = "" 
    #"scrypt" = "" 
   ##"sia" = ""  
    "sib" = " -i 21 " 
    "skein" = "" 
    "skein2" = ""
    "skunk" = "" 
    "timetravel" = "" 
    "timetravel10" = "" 
    #"tribus" = "" 
    "vanilla" = "" 
    "veltor" = " -i 23 " 
    "whirlpool" = ""
    "wildkeccak" = ""
    "x11" = " -i 21 " 
    "x11evo" = " -i 21 " 
    #"x11gost" = ""
    #"x13" = "" 
    "x14" = " -i 21 " 
    "x15" = "" 
    "x17" = " -i 21 " 
    #"xevan" = "" 
    #"yescrypt" = "" 
    "zr5" = ""
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = " -R 5 -a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}