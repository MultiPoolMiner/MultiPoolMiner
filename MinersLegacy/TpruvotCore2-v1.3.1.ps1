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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        # CPU Only algos 3/27/2018
        "yescrypt"       = "" #Yescrypt
        "axiom"          = "" #axiom
        
        # CPU & GPU - still profitable 31/03/2019
        "shavite3"       = "" #shavite3
        "timetravel"     = "" #Timetravel

        #GPU - never profitable 27/03/2018
        #"bastion"       = "" #bastion
        #"blake"         = "" #blake
        #"blake2s"       = "" #Blake2s
        #"blakecoin"     = "" #Blakecoin
        #"bmw"           = "" #bmw
        #"c11"           = "" #C11
        #"cryptolight"   = "" #cryptolight
        #"cryptonight"   = "" #CryptoNight
        #"decred"        = "" #Decred
        #"dmd-gr"        = "" #dmd-gr
        #"equihash"      = "" #Equihash
        #"ethash"        = "" #Ethash
        #"groestl"       = "" #Groestl
        #"jha"           = "" #JHA
        #"keccak"        = "" #Keccak
        #"keccakc"       = "" #keccakc
        #"lbry"          = "" #Lbry
        #"lyra2re"       = "" #lyra2re
        #"lyra2v2"       = "" #Lyra2RE2
        #"myr-gr"        = "" #MyriadGroestl
        #"neoscrypt"     = "" #NeoScrypt
        #"nist5"         = "" #Nist5
        #"pascal"        = "" #Pascal
        #"pentablake"    = "" #pentablake
        #"pluck"         = "" #pluck
        #"scrypt:N"      = "" #scrypt:N
        #"scryptjane:nf" = "" #scryptjane:nf
        #"sha256d"       = "" #sha256d
        #"sib"           = "" #Sib
        #"skein"         = "" #Skein
        #"skein2"        = "" #skein2
        #"skunk"         = "" #Skunk
        #"tribus"        = "" #Tribus
        #"vanilla"       = "" #BlakeVanilla
        #"veltor"        = "" #Veltor
        #"x11"           = "" #X11
        #"x11evo"        = "" #X11evo
        #"x13"           = "" #x13
        #"x14"           = "" #x14
        #"x15"           = "" #x15
        #"x16r"          = "" #x16r
        #"zr5"           = "" #zr5
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices = $Devices | Where-Object Type -EQ "CPU"
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

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b $Miner_Port$Parameters$CommonParameters" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
