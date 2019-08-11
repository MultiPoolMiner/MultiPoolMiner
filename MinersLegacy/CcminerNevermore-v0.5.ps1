using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "940EB4C246019216C8F95FFB2F2E65FA147B13A65756A38D660146672E47844B"
$Uri = "https://github.com/nemosminer/ccminerx16r-x16s/releases/download/v0.5/ccminerx16rx16s64-bit.7z"
$ManualUri = "https://github.com/nemosminer/ccminerx16r-x16s"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    "bitcore"     = " -a bitcore" #Timetravel10 and Bitcore are technically the same
    #"c11"         = " -a c11" #C11, NVIDIA-CcminerAlexis_v1.5 is faster
    #"equihash"   = " -a equihash" #Equihash - Beaten by Bminer by 30%
    "hmq1725"     = " -a hmq1725" #HMQ1725
    "hsr"         = " -a hsr" #HSR
    "jha"         = " -a jha" #JHA - NOT TESTED
    "keccak"      = " -a keccak" #Keccak
    "keccakc"     = " -a keccakc" #Keccakc
    "lyra2v2"     = " -a lyra2v2" #Lyra2RE2
    "lyra2z"      = " -a lyra2z" #Lyra2z
    "neoscrypt"   = " -a neoscrypt" #NeoScrypt
    "phi"         = " -a phi" #PHI
    "polytimos"   = " -a polytimos" #Polytimos - NOT TESTED
    "skein"       = " -a skein" #Skein
    "skunk"       = " -a skunk" #Skunk
    "timetravel"  = " -a timetravel" #Timetravel
    "tribus"      = " -a tribus" #Tribus
    "veltor"      = " -a veltor" #Veltor - NOT TESTED
    "x11evo"      = " -a x11evo" #X11evo
    "x16r"        = " -a x16r" #X16R
    #"x17"         = " -a x17" #X17, NVIDIA-CcminerAlexis_v1.5 is faster
    
    # ASIC - never profitable 24/06/2018
    #"blake"      = " -a blake" #blake
    #"blakecoin"  = " -a blakecoin" #Blakecoin
    #"blake2s"    = " -a blake2s" #Blake2s
    #"decred"     = " -a decred" #Decred
    #"groestl"    = " -a groestl" #Groestl
    #"lbry"       = " -a lbry" #Lbry
    #"myr-gr"     = " -a myr-gr" #MyriadGroestl
    #"nist5"      = " -a nist5" #Nist5
    #"quark"      = " -a quark" #Quark
    #"qubit"      = " -a qubit" #Qubit
    #"scrypt"     = " -a scrypt" #Scrypt
    #"sha256d"    = " -a sha256d" #sha256d
    #"sia"        = " -a sia" #SiaCoin
    #"sib"        = " -a sib" #Sib
    #"vanilla"    = " -a vanilla" #BlakeVanilla
    #"x11"        = " -a x11" #X11
    #"x13"        = " -a x13" #x13
    #"x14"        = " -a x14" #x14
    #"x15"        = " -a x15" #x15
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
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "C11"   {$WarmupTime = 60}
            default {$WarmupTime = 30}
        }

        [PSCustomObject]@{
            Name             = $Miner_Name
            BaseName         = $Miner_BaseName
            Version          = $Miner_Version
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API              = "Ccminer"
            Port             = $Miner_Port
            URI              = $Uri
            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
            PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
            WarmupTime = $WarmupTime
        }
    }
}
