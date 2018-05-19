using module ..\Include.psm1

$Path = ".\Bin\Sib-NVIDIA\ccminer_x11gost.exe"
$HashSHA256 = "CD8602A080728894570C9D29FC1423FB62AF1FA9CAF3913E609BA21777284DEE"
$Uri = "https://github.com/nicehash/ccminer-x11gost/releases/download/ccminer-x11gost_windows/ccminer_x11gost.7z"

$Commands = [PSCustomObject]@{
    "blake2s"   = "" #Blake2s
    "blakecoin" = "" #Blakecoin
    "c11"       = "" #C11
    "keccak"    = "" #Keccak
    "lyra2v2"   = "" #Lyra2RE2
    "neoscrypt" = "" #NeoScrypt
    "sib"       = "" #Sib
    "skein"     = "" #Skein
    "x11evo"    = "" #X11evo

    # ASIC - never profitable 12/05/2018
    #"decred" = "" #Decred
    #"lbry" = "" #Lbry
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"sib" = "" #Sib
    
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type             = "NVIDIA"
        Path             = $Path
        HashSHA256       = $HashSHA256
        Arguments        = "-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API              = "Ccminer"
        Port             = 4068
        URI              = $Uri
        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
        PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
    }
}
