. .\Include.ps1

$Path = ".\Bin\AMD-NiceHash\sgminer.exe"
$Uri = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-amd64.zip"

$Commands = [PSCustomObject]@{
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
    "blake" = "" #Blakecoin
    "vanilla" = " --intensity d" #BlakeVanilla
    #"cryptonight" = " --gpu-threads 1 --worksize 8 --rawintensity 896" #Cryptonight
    "decred" = "" #Decred
    #"equihash" = " --gpu-threads 2 --worksize 256" #Equihash
    #"ethash" = " --gpu-threads 1 --worksize 192 --xintensity 1024" #Ethash
    "groestlcoin" = " --gpu-threads 2 --worksize 128 --intensity d" #Groestl
    #"hmq1725" = "" #hmq1725
    "maxcoin" = "" #Keccak
    "lbry" = "" #Lbry
    "lyra2rev2" = " --gpu-threads 2 --worksize 128 --intensity d" #Lyra2RE2
    #"lyra2z" = " --worksize 32 --intensity 18" #Lyra2z
    "myriadcoin-groestl" = " --gpu-threads 2 --worksize 64 --intensity d" #MyriadGroestl
    "neoscrypt" = " --gpu-threads 1 --worksize 64 --intensity 11 --thread-concurrency 64" #NeoScrypt
    #"nist5" = "" #Nist5
    "pascal" = "" #Pascal
    "qubitcoin" = " --gpu-threads 2 --worksize 128 --intensity d" #Qubit
    "zuikkis" = "" #Scrypt
    "sia" = "" #Sia
    #"sib" = "" #Sib
    "skeincoin" = " --gpu-threads 2 --worksize 256 --intensity d" #Skein
    #"timetravel" = "" #Timetravel
    "darkcoin-mod" = " --gpu-threads 2 --worksize 128 --intensity d" #X11
    #"x11evo" = "" #X11evo
    #"x17" = "" #X17
    "yescrypt" = " --worksize 4 --rawintensity 256" #Yescrypt
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-listen -k $_ -o $($Pools.(Get-Algorithm($_)).Protocol)://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        Wrap = $false
        URI = $Uri
    }
}