using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-TPruvot\ccminer-x64.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.2.2-tpruvot/ccminer-x64-2.2.2-cuda9.7z"

$Commands = [PSCustomObject]@{
    "bitcore" = "" #Bitcore
    "blake2s" = "" #Blake2s
    "blakecoin" = "" #Blakecoin
    "vanilla" = "" #BlakeVanilla
    "c11" = "" #C11
    "cryptonight" = "" #CryptoNight
    "decred" = "" #Decred
    "equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    "groestl" = "" #Groestl
    "hmq1725" = "" #HMQ1725
    "jha" = "" #JHA
    "keccak" = "" #Keccak
    "lbry" = "" #Lbry
    "lyra2v2" = "" #Lyra2RE2
    "lyra2z" = "" #Lyra2z
    "myr-gr" = "" #MyriadGroestl
    "neoscrypt" = "" #NeoScrypt
    "nist5" = "" #Nist5
    "pascal" = "" #Pascal
    "quark" = "" #Quark
    "qubit" = "" #Qubit
    "scrypt" = "" #Scrypt
    "sia" = "" #Sia
    "sib" = "" #Sib
    "skein" = "" #Skein
    "skunk" = "" #Skunk
    "timetravel" = "" #Timetravel
    "tribus" = "" #Tribus
    "veltor" = "" #Veltor
    "x11" = "" #X11
    "x11evo" = "" #X11evo
    "x17" = "" #X17
    "yescrypt" = "" #Yescrypt
    #"xevan" = "" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}