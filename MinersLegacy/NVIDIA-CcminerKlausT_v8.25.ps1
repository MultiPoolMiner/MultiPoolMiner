﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer.exe"
$HashSHA256 = "FEB39973E6DE9DCC507C4919B05830AC58D2948AF24E206CA1ACE8933ED5EA29"
$Uri = "https://github.com/KlausT/ccminer/releases/download/8.25/ccminer-825-cuda100-x64.zip"
$ManualUri = "https://github.com/KlausT/ccminer"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 10.0.00
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "10.0.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        #GPU - profitable 25/11/2018
        #"c11"           = "" #C11/Flax
        "deep"          = "" #deep
        "dmd-gr"        = "" #dmd-gr
        "fresh"         = "" #fresh
        "fugue256"      = "" #Fugue256
        "jackpot"       = "" #Jackpot
        "keccak"        = "" #Keccak
        "luffa"         = "" #Luffa
        "lyra2v2"       = "" #Lyra2RE2
        "lyra2v3"       = "" #Lyra2RE3, new in 8.23
        "neoscrypt"     = "" #NeoScrypt
        "penta"         = "" #Pentablake
        "s3"            = "" #S3
        "skein"         = "" #Skein
        "whirl"         = "" #Whirlpool
        "whirlpoolx"    = "" #whirlpoolx
        "x17"           = "" #X17 Verge
        "yescrypt"      = "" #yescrypt

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
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

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
