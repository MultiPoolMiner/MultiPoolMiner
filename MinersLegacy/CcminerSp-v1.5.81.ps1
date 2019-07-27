using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "82477387C860517C5FACE8758BCB7AAC890505280BF713ACA9F86D7B306AC711"
$Uri = "https://github.com/sp-hash/ccminer/releases/download/1.5.81/release81.7z"
$ManualUri = "https://github.com/sp-hash/ccminer"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        #GPU - profitable 20/04/2018
        "bastion"       = "" #bastion
        #"c11"           = "" #C11/Flax
        "credit"        = "" #Credit
        "deep"          = "" #deep
        "dmd-gr"        = "" #dmd-gr
        "fresh"         = "" #fresh
        "fugue256"      = "" #Fugue256
        "heavy"         = "" #heavy
        "jackpot"       = "" #JackPot
        "keccak"        = "" #Keccak
        "luffa"         = "" #Luffa
        "mjollnir"      = "" #Mjollnir
        "pentablake"    = "" #pentablake
        "scryptjane:nf" = "" #scryptjane:nf
        "s3"            = "" #S3
        "spread"        = "" #Spread
        #"x17"           = "" #x17, NVIDIA-CcminerAlexis_v1.5 is faster

        # ASIC - never profitable 24/06/2018
        #"blake"         = "" #blake
        #"blakecoin"     = "" #Blakecoin
        #"blake2s"       = "" #Blake2s
        #"decred"        = "" #Decred
        #"groestl"       = "" #Groestl
        #"lbry"          = "" #Lbry
        #"lyra2"         = "" #lyra2RE
        #"myr-gr"        = "" #MyriadGroestl
        #"nist5"         = "" #Nist5
        #"quark"         = "" #Quark
        #"qubit"         = "" #Qubit
        #"scrypt"        = "" #Scrypt
        #"scrypt:N"      = "" #scrypt:N
        #"sha256d"       = "" #sha256d Bitcoin
        #"sia"           = "" #SiaCoin
        #"vanilla"       = "" #BlakeVanilla
        #"x11"           = "" #X11
        #"x13"           = "" #x13
        #"x14"           = "" #x14
        #"x15"           = "" #x15
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
