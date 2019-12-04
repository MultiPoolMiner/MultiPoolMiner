using module ..\Include.psm1

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

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA")

#Miner requires CUDA 10.0.00
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ", ""
$RequiredCUDAVersion = "10.0.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject]@{ 
    #GPU - profitable 25/11/2018
    #"c11"        = " -a c11" #C11/Flax
    "deep"       = " -a deep" #deep
    "dmd-gr"     = " -a dmd-gr" #dmd-gr
    "fresh"      = " -a fresh" #fresh
    "fugue256"   = " -a fugue256" #Fugue256
    "jackpot"    = " -a jackpot" #Jackpot
    "keccak"     = " -a keccak" #Keccak
    "luffa"      = " -a luffa" #Luffa
    #"lyra2v2"    = " -a lyra2v2" #Lyra2RE2; CcminerAlexis-v1.5 is faster
    "lyra2v3"    = " -a lyra2v3 --intensity 21" #Lyra2RE3, new in 8.23
    "neoscrypt"  = " -a neoscrypt --intensity 16" #Neoscrypt
    "penta"      = " -a penta" #Pentablake
    "s3"         = " -a s3" #S3
    "skein"      = " -a skein" #Skein
    "whirlpool"  = " -a whirl" #Whirlpool
    "whirlpoolx" = " -a whirlpoolx" #whirlpoolx
    #"x17"        = " -a x17" #X17 Verge, NVIDIA-CcminerAlexis-v1.5 is faster
    #"yescrypt"   = " -a yescrypt" #yescrypt

    #ASIC - never profitable 25/11/2018
    #"bitcoin"    = " -a bitcoin" #Bitcoin
    #"blake"      = " -a blake" #Blake
    #"blakecoin"  = " -a blakecoin" #Blakecoin
    #"blake2s"    = " -a blake2s" #Blake2s
    #"groestl"    = " -a groestl" #Groestl
    #"keccak"     = " -a keccak" #Keccak-256 (Maxcoin)
    #"myr-gr"     = " -a myr-gr" #MyriadGroestl
    #"nist5"      = " -a nist5" #Nist5
    #"quark"      = " -a quark" #Quark
    #"qubit"      = " -a qubit" #Qubit
    #"vanilla"    = " -a vanilla" #BlakeVanilla
    #"sha256d"    = " -a sha256d" #sha256d
    #"sia"        = " -a sia" #SiaCoin
    #"x11"        = " -a x11" #X11
    #"x13"        = " -a x13" #x13
    #"x14"        = " -a x14" #x14
    #"x15"        = " -a x15" #x15
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Algorithm_Norm = @(@(Get-Algorithm ($_ -split '-' | Select-Object -First 1) | Select-Object) + @($_ -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'; $_ } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> } | ForEach-Object { 
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) { 
            "C11" { $WarmupTime = 60 }
            default { $WarmupTime = 30 }
        }

        [PSCustomObject]@{ 
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
        }
    }
}
