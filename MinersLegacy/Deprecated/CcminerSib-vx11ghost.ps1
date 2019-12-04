using module ..\Include.psm1

param(
    [PSCustomObject]$Pools, 
    [PSCustomObject]$Stats, 
    [PSCustomObject]$Config, 
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\ccminer_x11gost.exe"
$HashSHA256 = "CD8602A080728894570C9D29FC1423FB62AF1FA9CAF3913E609BA21777284DEE"
$Uri = "https://github.com/nicehash/ccminer-x11gost/releases/download/ccminer-x11gost_windows/ccminer_x11gost.7z"
$ManualUri = "https://github.com/nicehash/ccminer-x11gost"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Commands = [PSCustomObject]@{ 
    "blake2s"   = " -a blake2s" #Blake2s
    "blakecoin" = " -a blakecoin" #Blakecoin
    "c11"       = " -a c11" #C11
    "keccak"    = " -a keccak" #Keccak
    "lyra2v2"   = " -a lyra2v2" #Lyra2RE2
    "neoscrypt" = " -a neoscrypt" #NeoScrypt
    "skein"     = " -a skein" #Skein
    "x11evo"    = " -a x11evo" #X11evo

    #ASIC - never profitable 24/06/2018
    #"decred"    = " -a decred" #Decred
    #"lbry"      = " -a lbry" #Lbry
    #"myr-gr"    = " -a myr-gr" #MyriadGroestl
    #"nist5"     = " -a nist5" #Nist5
    #"sib"       = " -a sib" #Sib
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = "" }

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA")
$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Algorithm_Norm = @(@(Get-Algorithm ($_ -split '-' | Select-Object -First 1) | Select-Object) + @($_ -split '-' | Select-Object -Skip 1) | Select-Object -Unique) -join '-'; $_ } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> } | ForEach-Object { 
        $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) { 
            "C11" { $WarmupTime = 60 }
            default { $WarmupTime = 30 }
        }

        [PSCustomObject]@{ 
            Name             = $Miner_Name
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ',')" -replace "\s+", " ").trim()
            HashRates        = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API              = "Ccminer"
            Port             = $Miner_Port
            URI              = $Uri
            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
            PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
            WarmupTime       = $WarmupTime
        }
    }
}
