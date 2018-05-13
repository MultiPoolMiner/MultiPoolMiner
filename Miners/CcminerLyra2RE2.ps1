using module ..\Include.psm1

$Path = ".\Bin\Lyra2RE2-NVIDIA\ccminer.exe"
$HashSHA256 = "998AEBAA80CD6D2B758A5B4798D6AC929745B88D81735587798F616D7E2F3B23"
$Uri = "https://github.com/nicehash/ccminer-nanashi/releases/download/1.7.6-r6/ccminer.zip"

$Commands = [PSCustomObject]@{
    "blake2s"   = "" #Blake2s
    "blakecoin" = "" #Blakecoin
    "c11"       = "" #C11
    "groestl"   = "" #Groestl
    "keccak"    = "" #Keccak
    "lyra2v2"   = "" #Lyra2RE2
    "neoscrypt" = "" #NeoScrypt
    "skein"     = "" #Skein
    "x17"       = "" #X17
    
    # ASIC - never profitable 12/05/2018
    #"decred"   = "" #Decred
    #"myr-gr"   = "" #MyriadGroestl
    #"nist5"    = "" #Nist5
    #"qubit"    = "" #qubit
    #"quark"    = "" #Quark
    #"sib"      = "" #Sib

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
    }
}
