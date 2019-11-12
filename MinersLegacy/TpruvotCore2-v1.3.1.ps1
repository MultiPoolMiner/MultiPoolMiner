using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\CPU-Tpruvot_v1.3.1\cpuminer-gw64-core2.exe"
$HashSHA256 = "3EA2A09BE5CFFC0501FC07F6744233A351371E2CF93F544768581EE1E6613454"
$Uri = "https://github.com/tpruvot/cpuminer-multi/releases/download/v1.3.1-multi/cpuminer-multi-rel1.3.1-x64.zip"
$ManualUri = "https://github.com/tpruvot/cpuminer-multi"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    # CPU Only algos 3/27/2018
    "yescrypt"       = " -a yescrypt" #Yescrypt
    "axiom"          = " -a axiom" #axiom
    
    # CPU & GPU - still profitable 31/03/2019
    "shavite3"       = " -a shavite3" #shavite3
    "timetravel"     = " -a timetravel" #Timetravel

    #GPU - never profitable 27/03/2018
    #"bastion"       = " -a bastion" #bastion
    #"blake"         = " -a blake" #blake
    #"blake2s"       = " -a blake2s" #Blake2s
    #"blakecoin"     = " -a blakecoin" #Blakecoin
    #"bmw"           = " -a bmw" #bmw
    #"c11"           = " -a c11" #C11
    #"cryptolight"   = " -a cryptolight" #cryptolight
    #"cryptonight"   = " -a cryptonight" #CryptoNight
    #"decred"        = " -a decred" #Decred
    #"dmd-gr"        = " -a dmd-gr" #dmd-gr
    #"equihash"      = " -a equihash" #Equihash
    #"ethash"        = " -a ethash" #Ethash
    #"groestl"       = " -a groestl" #Groestl
    #"jha"           = " -a jha" #JHA
    #"keccak"        = " -a keccak" #Keccak
    #"keccakc"       = " -a keccakc" #keccakc
    #"lbry"          = " -a lbry" #Lbry
    #"lyra2re"       = " -a lyra2re" #lyra2re
    #"lyra2v2"       = " -a lyra2v2" #Lyra2RE2
    #"myr-gr"        = " -a myr-gr" #MyriadGroestl
    #"neoscrypt"     = " -a neoscrypt" #NeoScrypt
    #"nist5"         = " -a nist5" #Nist5
    #"pascal"        = " -a pascal" #Pascal
    #"pentablake"    = " -a pentablake" #pentablake
    #"pluck"         = " -a pluck" #pluck
    #"scrypt:N"      = " -a scrypt:N" #scrypt:N
    #"scryptjane:nf" = " -a scryptjane:nf" #scryptjane:nf
    #"sha256d"       = " -a sha256d" #sha256d
    #"sib"           = " -a sib" #Sib
    #"skein"         = " -a skein" #Skein
    #"skein2"        = " -a skein2" #skein2
    #"skunk"         = " -a skunk" #Skunk
    #"tribus"        = " -a tribus" #Tribus
    #"vanilla"       = " -a vanilla" #BlakeVanilla
    #"veltor"        = " -a veltor" #Veltor
    #"x11"           = " -a x11" #X11
    #"x11evo"        = " -a x11evo" #X11evo
    #"x13"           = " -a x13" #x13
    #"x14"           = " -a x14" #x14
    #"x15"           = " -a x15" #x15
    #"x16r"          = " -a x16r" #x16r
    #"zr5"           = " -a zr5" #zr5
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}


#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices = $Devices | Where-Object Type -EQ "CPU"
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1
                
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

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
            Arguments  = ("$Command$CommonCommands -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            WarmupTime = $WarmupTime
        }
    }
}
