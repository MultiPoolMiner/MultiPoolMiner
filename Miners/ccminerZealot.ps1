 using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Zealot\z-enemy.exe"
$HashSHA256 = "59e413741711e2984a1911db003fee807941f9a9f838cb96ff050194bc74bfce"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/zenemy108/z-enemy-1.08-release.zip"
#$ManualUri = "https://mega.nz/#!5WACFRTT!tV1vUsFdBIDqCzBrcMoXVR2G9YHD6xqct5QB2nBiuzM"

$Commands = [PSCustomObject]@{
    "bitcore" = "" #Bitcore
    "jha" = "" #JHA - NOT TESTED
    "phi" = "" #PHI
    "poly" = "" #Polytmos - NOT TESTED
    "veltor" = "" #Veltor - NOT TESTED
    "x12" = "" #X12 - NOT TESTED
    "x14" = "" #X14 - NOT TESTED
    "x16r" = "" #Rave
    "x16s" = "" #Pigeon
    # ASIC - never profitable 20/04/2018
    #"cryptonight" = "" #CryptoNight - NOT TESTED
    #"decred" = "" #Decred - NOT TESTED
    #"vanilla" = "" #BlakeVanilla - NOT TESTED
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
