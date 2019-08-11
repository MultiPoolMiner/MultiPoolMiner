using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "1974bab01a30826497a76b79e227f3eb1c9eb9ffa6756c801fcd630122bdb5c7"
$Uri = "https://github.com/Nanashi-Meiyo-Meijin/ccminer/releases/download/v2.2-mod-r2/2.2-mod-r2-CUDA9.binary.zip"
$ManualUri = "https://github.com/Nanashi-Meiyo-Meijin/ccminer_v2.2_mod_r2"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "bastion"       = " -a bastion" #bastion
    "bitcore"       = " -a bitcore" #Timetravel10 and Bitcore are technically the same
    "bmw"           = " -a bmw" #bmw
    "c11"           = " -a c11" #C11
    "cryptonight"   = " -a cryptonight" #CryptoNight
    "deep"          = " -a deep" #deep
    "dmd-gr"        = " -a dmd-gr" #dmd-gr
    "fresh"         = " -a fresh" #fresh
    "fugue256"      = " -a fugue256" #Fugue256
    "heavy"         = " -a heavy" #heavy
    "hmq1725"       = " -a hmq1725" #HMQ1725
    "jha"           = " -a jha" #JHA
    "keccak"        = " -a keccak" #Keccak
    "luffa"         = " -a luffa" #Luffa
    "lyra2v2"       = " -a lyra2v2" #Lyra2RE2
    "lyra2z"        = " -a lyra2z" #Lyra2z, ZCoin
    "mjollnir"      = " -a mjollnir" #Mjollnir
    "neoscrypt"     = " -a neoscrypt" #NeoScrypt
    "penta"         = " -a penta" #Pentablake
    "scryptjane:nf" = " -a scryptjane:nf" #scryptjane:nf
    "sha256t"       = " -a sha256t" #sha256t
    "skein"         = " -a skein" #Skein
    "skein2"        = " -a skein2" #skein2
    "skunk"         = " -a skunk" #Skunk
    "s3"            = " -a s3" #S3
    "shavite3"      = " -a shavite3" #shavite3
    "timetravel"    = " -a timetravel" #Timetravel
    "tribus"        = " -a tribus" #Tribus
    "veltor"        = " -a veltor" #Veltor
    #"whirlpool"    = " -a whirlpool" #Whirlpool
    "wildkeccak"    = " -a wildkeccak" #wildkeccak
    "x11evo"        = " -a x11evo" #X11evo
    "x17"           = " -a x17" #x17
    "zr5"           = " -a zr5" #zr5

    # ASIC - never profitable 11/08/2018
    #"blake"        = " -a blake" #blake
    #"blakecoin"    = " -a blakecoin" #Blakecoin
    #"blake2s"      = " -a blake2s" #Blake2s
    #"cryptolight"  = " -a cryptolight" #cryptolight
    #"cryptonight"  = " -a cryptonight" #CryptoNight
    #"decred"       = " -a decred" #Decred
    #"groestl"      = " -a groestl" #Groestl
    #"lbry"         = " -a lbry" #Lbry
    #"lyra2"        = " -a lyra2" #lyra2re
    #"myr-gr"       = " -a myr-gr" #MyriadGroestl
    #"nist5"        = " -a nist5" #Nist5
    #"quark"        = " -a quark" #Quark
    #"qubit"        = " -a qubit" #Qubit
    #"scrypt"       = " -a scrypt" #Scrypt
    #"scrypt:N"     = " -a scrypt:N" #scrypt:N
    #"sha256d"      = " -a sha256d" #sha256d
    #"sia"          = " -a sia" #SiaCoin
    #"sib"          = " -a sib" #Sib
    #"vanilla"      = " -a vanilla" #BlakeVanilla
    #"x11"          = " -a x11" #X11
    #"x13"          = " -a x13" #x13
    #"x14"          = " -a x14" #x14
    #"x15"          = " -a x15" #x15
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1
    
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "C11"   {$WarmupTime = 60}
            default {$WarmupTime = 30}
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            WarmupTime = $WarmupTime
        }
    }
}
