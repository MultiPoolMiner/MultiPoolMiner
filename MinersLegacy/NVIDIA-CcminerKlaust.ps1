using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-KlausT\ccminer.exe"
$HashSHA256 = "0345D2D274404F166C0927FC64683A6C86C2D0940E1518C6808244D6EFBB7F22"
$Uri = "https://github.com/nemosminer/ccminerKlausT-r11-fix/releases/download/r11-fix/ccminerKlausTr11.7z"
$ManualUri = "https://github.com/nemosminer"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "c11"           = "" #C11
    "deep"          = "" #deep
    "dmd-gr"        = "" #dmd-gr
    "fresh"         = "" #fresh
    "fugue256"      = "" #Fugue256
    "jackpot"       = "" #Jackpot
    "keccak"        = "" #Keccak
    "luffa"         = "" #Luffa
    "lyra2v2"       = "" #Lyra2RE2
    "neoscrypt"     = "" #NeoScrypt
    "penta"         = "" #Pentablake
    "skein"         = "" #Skein
    "s3"            = "" #S3
    "veltor"        = "" #Veltor
    "whirlpool"     = "" #Whirlpool
    "whirlpoolx"    = "" #whirlpoolx
    "x17"           = "" #X17 Verge
    "yescrypt"      = "" #yescrypt
    "yescryptR8"    = ""
    "yescryptR16"   = "" #YescryptR16 #Yenten
    "yescryptR16v2" = "" #PPN    

    # ASIC - never profitable 24/06/2018
    #"blake"      = "" #blake
    #"blakecoin"  = "" #Blakecoin
    #"blake2s"    = "" #Blake2s
    #"groestl"    = "" #Groestl
    #"myr-gr"     = "" #MyriadGroestl
    #"nist5"      = "" #Nist5
    #"quark"      = "" #Quark
    #"qubit"      = "" #Qubit
    #"vanilla"    = "" #BlakeVanilla
    #"sha256d"    = "" #sha256d
    #"sia"        = "" #SiaCoin
    #"x11"        = "" #X11
    #"x13"        = "" #x13
    #"x14"        = "" #x14
    #"x15"        = "" #x15
}

$CommonCommmands = ""

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

# Miner requires CUDA 9.2
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        [PSCustomObject]@{
            Name           = $Miner_Name
            DeviceName     = $Miner_Device.Name
            Path           = $Path
            HashSHA256     = $HashSHA256
            Arguments      = ("-a $_ -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API            = "Ccminer"
            Port           = $Miner_Port
            URI        = $Uri
        }
    }
}
