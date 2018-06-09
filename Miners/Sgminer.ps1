using module ..\Include.psm1

$Path = ".\Bin\AMD-NiceHash\sgminer.exe"
$HashSHA256 = "7A29E1280898D049BEE35B1CE4A6F05A7B3A3219AC805EA51BEFD8B9AFDE7D85"
$Uri = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-amd64.zip"

$Commands = [PSCustomObject]@{
    "groestlcoin"  = " --gpu-threads 2 --worksize 128 --intensity d" #Groestl
    "lbry"         = "" #Lbry
    "lyra2rev2"    = " --gpu-threads 2 --worksize 128 --intensity d" #Lyra2RE2
    "neoscrypt"    = " --gpu-threads 1 --worksize 64 --intensity 15" #NeoScrypt
    "sibcoin-mod"  = "" #Sib
    "skeincoin"    = " --gpu-threads 2 --worksize 256 --intensity d" #Skein
    "yescrypt"     = " --worksize 4 --rawintensity 256" #Yescrypt

    # ASIC - never profitable 23/05/2018    
    #"blake2s"     = "" #Blake2s
    #"blake"       = "" #Blakecoin
    #"cryptonight" = " --gpu-threads 1 --worksize 8 --rawintensity 896" #CryptoNight
    #"decred"      = "" #Decred
    #"lbry"        = "" #Lbry
    #"maxcoin"     = "" #Keccak
    #"myriadcoin-groestl" = " --gpu-threads 2 --worksize 64 --intensity d" #MyriadGroestl
    #"nist5"       = "" #Nist5
    #"pascal"      = "" #Pascal
    #"vanilla"     = " --intensity d" #BlakeVanilla
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = "AMD"
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Xgminer"
        Port       = 4028
        URI        = $Uri
    }
}