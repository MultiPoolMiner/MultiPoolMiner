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

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        "bitcore"     = "" #Timetravel10 and Bitcore are technically the same
        #"c11"         = "" #C11, NVIDIA-CcminerAlexis_v1.5 is faster
        #"equihash"   = "" #Equihash - Beaten by Bminer by 30%
        "hmq1725"     = "" #HMQ1725
        "hsr"         = "" #HSR
        "jha"         = "" #JHA - NOT TESTED
        "keccak"      = "" #Keccak
        "keccakc"     = "" #Keccakc
        "lyra2v2"     = "" #Lyra2RE2
        "lyra2z"      = "" #Lyra2z
        "neoscrypt"   = "" #NeoScrypt
        "phi"         = "" #PHI
        "polytimos"   = "" #Polytimos - NOT TESTED
        "skein"       = "" #Skein
        "skunk"       = "" #Skunk
        "timetravel"  = "" #Timetravel
        "tribus"      = "" #Tribus
        "veltor"      = "" #Veltor - NOT TESTED
        "x11evo"      = "" #X11evo
        "x12"         = "" #X12 - NOT TESTED
        "x16r"        = "" #X16R
        #"x17"         = "" #X17, NVIDIA-CcminerAlexis_v1.5 is faster
       
        # ASIC - never profitable 24/06/2018
        #"blake"      = "" #blake
        #"blakecoin"  = "" #Blakecoin
        #"blake2s"    = "" #Blake2s
        #"decred"     = "" #Decred
        #"groestl"    = "" #Groestl
        #"lbry"       = "" #Lbry
        #"myr-gr"     = "" #MyriadGroestl
        #"nist5"      = "" #Nist5
        #"quark"      = "" #Quark
        #"qubit"      = "" #Qubit
        #"scrypt"     = "" #Scrypt
        #"sha256d"    = "" #sha256d
        #"sia"        = "" #SiaCoin
        #"sib"        = "" #Sib
        #"vanilla"    = "" #BlakeVanilla
        #"x11"        = "" #X11
        #"x13"        = "" #x13
        #"x14"        = "" #x14
        #"x15"        = "" #x15
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1
        
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get parameters for active miner devices
        if ($Miner_Config.Parameters.$Algorithm_Norm) {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
        }
        elseif ($Miner_Config.Parameters."*") {
            $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
        }
        else {
            $Parameters = Get-ParameterPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index
        }

        Switch ($Algorithm_Norm) {
            "X16R"  {$IntervalMultiplier = 5}
            default {$IntervalMultiplier = 1}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            BaseName           = $Miner_BaseName
            Version            = $Miner_Version
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Ccminer"
            Port               = $Miner_Port
            URI                = $Uri
            IntervalMultiplier = $IntervalMultiplier
            PrerequisitePath   = "$env:SystemRoot\System32\msvcr120.dll"
            PrerequisiteURI    = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
        }
    }
}
