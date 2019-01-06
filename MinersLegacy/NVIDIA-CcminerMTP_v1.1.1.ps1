using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "E6AAB3D9F200506A081F576D0653E47205A704577F1F55984AFF736DFA7B734A"
$Uri = "https://github.com/zcoinofficial/ccminer/releases/download/1.1.4/ccminer.exe"
$ManualUri = "https://github.com/zcoinofficial/ccminer"

# Miner requires CUDA 10-0.00 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "10.0.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{
	"bmw"         = "" #BMW 256
	"c11/flax"    = "" #X11 variant
	"deep"        = "" #Deepcoin
	"dmd-gr"      = "" #Diamond-Groestl
	"fresh"       = "" #Freshcoin (shavite 80)
	"fugue256"    = "" #Fuguecoin
	"heavy"       = "" #Heavycoin
	"jackpot"     = "" #Jackpot
	"keccak"      = "" #Keccak-256 (Maxcoin)
	"luffa"       = "" #Joincoin
	"lyra2"       = "" #CryptoCoin
	"lyra2Z"      = "" #ZCoin
	"m7"          = "" #m7 (crytonite) hash
	"mjollnir"    = "" #Mjollnircoin
	"mtp"         = "" #Zcoin
	"neoscrypt"   = "" #FeatherCoin, Phoenix, UFO...
	"penta"       = "" #Pentablake hash (5x Blake 512)
	"scrypt-jane" = "" #Scrypt-jane Chacha
	"skein"       = "" #Skein SHA2 (Skeincoin)
	"skein2"      = "" #Double Skein (Woodcoin)
	"s3"          = "" #S3 (1Coin)
	"veltor"      = "" #Thorsriddle streebog
	"whirlcoin"   = "" #Old Whirlcoin (Whirlpool algo)
	"whirlpool"   = "" #Whirlpool algo
	"x11evo"      = "" #Permuted x11 (Revolver)
	"x17"         = "" #X17
	"zr5"         = "" #ZR5 (ZiftrCoin)
    
    # ASIC - never profitable 22/12/2018
	#"blake"       = "" #Blake 256 (SFR)
    #"Bitcoin"     = "" #BitCoin
    #"decred"      = "" #Decred
	#"groestl"     = "" #Groestlcoin
    #"lbry"        = "" #Lbry
	#"lyra2v2"     = "" #VertCoin
    #"myr-gr"      = "" #MyriadGroestl
    #"nist5"       = "" #Nist5
    #"qubit"       = "" #Qubit
    #"quark"       = "" #Quark
	#"scrypt"      = "" #Scrypt
	#"sia"         = "" #SIA (Blake2B)
	#"sib"         = "" #Sibcoin (X11+Streebog)
	#"x11"         = "" #X11 (DarkCoin)
	#"x13"         = "" #X13 (MaruCoin)
	#"x15"         = "" #X15
	#"vanilla"     = "" #Blake256-8 (VNL)
    #"x12"         = "" #X12
    #"x14"         = "" #X14
}
$CommonCommmands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 3

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
