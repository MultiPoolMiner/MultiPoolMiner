using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "EF4CCDEAF686C90A809F9A6A3E41298D4E9A6DDCACB9F73F9C7F59ADCCB688B7"
$Uri = "https://github.com/nemosminer/ccminerKlausTyescrypt/releases/download/v7/ccminerKlausTyescrypt.7z"
$ManualUri = "https://github.com/nemosminer/ccminer-KlausT-8.23-mod-r1"
$Port = "40{0:d2}"

# Miner requires CUDA 10.0.00
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "10.0.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{
    #GPU - profitable 25/11/2018
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
    "s3"            = "" #S3
    "skein"         = "" #Skein
    "whirl"         = "" #Whirlpool
    "whirlpoolx"    = "" #whirlpoolx
    "x17"           = "" #X17 Verge
    "yescrypt"      = "" #yescrypt
    "yescryptr8"    = "" #yescryptr8
    "yescryptr16"   = " -i 12.5" #YescryptR16 #Yenten
    "yescryptr16v2" = " -i 12.5" #PPTP
    "yescryptr24"   = "" #JagariCoinR
    "yescryptr32"   = " -i 12.5" #WAVI

    # ASIC - never profitable 25/11/2018
    #"bitcoin"    = "" #Bitcoin
    #"blake"      = "" #Blake
    #"blakecoin"  = "" #Blakecoin
    #"blake2s"    = "" #Blake2s
    #"groestl"    = "" #Groestl
	#"keccak"     = "" #Keccak-256 (Maxcoin)
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

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        
    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = "$Name-$($Miner_Device.count)x$($Miner_Device.Model_Norm | Sort-Object -unique)"
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
