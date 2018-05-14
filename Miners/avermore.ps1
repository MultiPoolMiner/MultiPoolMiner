using module ..\Include.psm1

$Path = ".\Bin\AMD-Avermore1.4\sgminer.exe"
$HashSHA256 = "c28ead031f5e7a73c5706e3e1d8b9f65cdc7591f919548cb69d8bbfddae43cad"
$Uri = "https://github.com/brian112358/avermore-miner/releases/download/v1.4/avermore-v1.4-windows.zip"

$Commands = [PSCustomObject]@{
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
    "blake" = "" #Blakecoin
    "vanilla" = " --intensity d" #BlakeVanilla
    #"c11" = "" #C11
    #"cryptonight" = " --gpu-threads 1 --worksize 8 --rawintensity 896" #CryptoNight
    "decred" = "" #Decred
    #"equihash" = " --gpu-threads 2 --worksize 256" #Equihash
    #"ethash" = " --gpu-threads 1 --worksize 192 --xintensity 1024" #Ethash
    "groestlcoin" = " --gpu-threads 2 --worksize 128 --intensity d" #Groestl
    #"hmq1725" = "" #HMQ1725
    #"jha" = "" #JHA
    "maxcoin" = "" #Keccak
    "lbry" = "" #Lbry
    "lyra2rev2" = " --gpu-threads 2 --worksize 128 --intensity d" #Lyra2RE2
    #"lyra2z" = " --worksize 32 --intensity 18" #Lyra2z
    "myriadcoin-groestl" = " --gpu-threads 2 --worksize 64 --intensity d" #MyriadGroestl
    "neoscrypt" = " --gpu-threads 1 --worksize 64 --intensity 15" #NeoScrypt
    #"nist5" = "" #Nist5
    "pascal" = "" #Pascal
    "sibcoin-mod" = "" #Sib
    "skeincoin" = " --gpu-threads 2 --worksize 256 --intensity d" #Skein
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"veltor" = "" #Veltor
    #"x11evo" = "" #X11evo
    #"x17" = "" #X17
    "x16R" = "" #X16r   
    "x16S" = "" #X16s
    "yescrypt" = " --worksize 4 --rawintensity 256" #Yescrypt
    #"xevan-mod" = " --intensity 15" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        HashSHA256 = $HashSHA256
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}
