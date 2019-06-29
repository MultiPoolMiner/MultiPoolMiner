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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        #GPU - profitable 20/04/2018
        "bastion"       = "" #bastion
        "bitcore"       = "" #Timetravel10 and Bitcore are technically the same
        "bmw"           = "" #bmw
        "c11"           = "" #C11
        "cryptonight"   = "" #CryptoNight
        "deep"          = "" #deep
        "dmd-gr"        = "" #dmd-gr
        "fresh"         = "" #fresh
        "fugue256"      = "" #Fugue256
        "heavy"         = "" #heavy
        "hmq1725"       = "" #HMQ1725
        "jha"           = "" #JHA
        "keccak"        = "" #Keccak
        "luffa"         = "" #Luffa
        "lyra2v2"       = "" #Lyra2RE2
        "lyra2z"        = "" #Lyra2z, ZCoin
        "mjollnir"      = "" #Mjollnir
        "neoscrypt"     = "" #NeoScrypt
        "penta"         = "" #Pentablake
        "scryptjane:nf" = "" #scryptjane:nf
        "sha256t"       = "" #sha256t
        "skein"         = "" #Skein
        "skein2"        = "" #skein2
        "skunk"         = "" #Skunk
        "s3"            = "" #S3
        "shavite3"      = "" #shavite3
        "timetravel"    = "" #Timetravel
        "tribus"        = "" #Tribus
        "veltor"        = "" #Veltor
        #"whirlpool"    = "" #Whirlpool
        "wildkeccak"    = "" #wildkeccak
        "x11evo"        = "" #X11evo
        "x17"           = "" #x17
        "zr5"           = "" #zr5

        # ASIC - never profitable 11/08/2018
        #"blake"        = "" #blake
        #"blakecoin"    = "" #Blakecoin
        #"blake2s"      = "" #Blake2s
        #"cryptolight"  = "" #cryptolight
        #"cryptonight"  = "" #CryptoNight
        #"decred"       = "" #Decred
        #"groestl"      = "" #Groestl
        #"lbry"         = "" #Lbry
        #"lyra2"        = "" #lyra2re
        #"myr-gr"       = "" #MyriadGroestl
        #"nist5"        = "" #Nist5
        #"quark"        = "" #Quark
        #"qubit"        = "" #Qubit
        #"scrypt"       = "" #Scrypt
        #"scrypt:N"     = "" #scrypt:N
        #"sha256d"      = "" #sha256d
        #"sia"          = "" #SiaCoin
        #"sib"          = "" #Sib
        #"vanilla"      = "" #BlakeVanilla
        #"x11"          = "" #X11
        #"x13"          = "" #x13
        #"x14"          = "" #x14
        #"x15"          = "" #x15
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
        $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

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

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
