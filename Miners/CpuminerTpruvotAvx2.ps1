using module ..\Include.psm1

$Path = ".\Bin\CPU-TPruvot\cpuminer-gw64-avx2.exe"
$Uri = "https://github.com/tpruvot/cpuminer-multi/releases/download/v1.3.1-multi/cpuminer-multi-rel1.3.1-x64.zip"

$Commands = [PSCustomObject]@{
    "blake2s" = "" #Blake2s
    "blakecoin" = "" #Blakecoin
    "vanilla" = "" #BlakeVanilla
    "c11" = "" #C11
    "cryptonight" = "" #CryptoNight
    "decred" = "" #Decred
    "groestl" = "" #Groestl
    "keccak" = "" #Keccak
    "lyra2rev2" = "" #Lyra2RE2
    "myr-gr" = "" #MyriadGroestl
    "neoscrypt" = "" #NeoScrypt
    "nist5" = "" #Nist5
    "sib" = "" #Sib
    "skein" = "" #Skein
    "timetravel" = "" #Timetravel
    "x11evo" = "" #X11evo
    "x17" = "" #X17
    "xevan" = "" #Xevan
    "yescrypt" = "" #Yescrypt
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "CPU"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4048
        URI = $Uri
    }
}