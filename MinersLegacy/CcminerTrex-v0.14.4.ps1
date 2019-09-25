using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\t-rex.exe"
$HashSHA256 = "8481F8DB9F7CA2F2A1828337A13CFF2BFD680A5A78CC68565F7B65D339042272"
$Uri = "https://github.com/trexminer/T-Rex/releases/download/0.14.4/t-rex-0.14.4-win-cuda10.0.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4432704.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    "AstralHash"  = " -a astralhash -i 23" #GltAstralHash, new in 0.8.6
    "Balloon"     = " -a balloon -i 23" #Balloon, new in 0.6.2
    "BCD"         = " -a bcd -i 24" #BitcoinDiamond, new in 0.6.5
    "Bitcore"     = " -a bitcore -i 26" #Timetravel10 and Bitcore are technically the same
    "C11"         = " -a c11 -i 26" #C11
    "Dedal"       = " -a dedal -i 23" #Defal, re-added in 0.13.0
    "Geek"        = " -a geek -i 23" #Geek, new in 0.8.0
    # "HMQ1725"     = " -a hmq1725" #Hmq1725, new in 0.6.4; NVIDIA-CryptoDredge_v0.21.0 is faster
    "Honeycomb"   = " -a honeycomb -i 26" #Honeycomb, new in 12.0
    "JeongHash"   = " -a jeonghash -i 23" #GltJeongHash, new in 0.8.6
    "Lyra2Z"      = " -a lyra2z" #Lyra2z
    "MTP"         = " -a mtp -i 24" #MTP, new in 0.10.2
    "MTPNiceHash" = " -a mtp -i 24" #MTP, new in 0.10.2
    "PadiHash"    = " -a padihash -i 23" #GltPadilHash, new in 0.8.6
    "PawelHash"   = " -a pawelhash -i 23" #GltPawelHash, new in 0.8.6
    "Phi"         = " -a phi" #Phi
    "Polytimos"   = " -a polytimos -i 26" #Polytimos, new in 0.6.3
    "SHA256q"     = " -a sha256q -i 26" #Sha256q, new in 0.9.1
    "SHA256t"     = " -a sha256t -i 23" #Sha256t
    "Skunk"       = " -a skunk -i 26" #Skunk, new in 0.6.3
    "Sonoa"       = " -a sonoa -i 25" #Sonoa, new in 0.6.1
    "Timetravel"  = " -a timetravel -i 25" #Timetravel
    "Tribus"      = " -a tribus -i 26" #Tribus
    "X16r"        = " -a x16r -i 25" #X16r
    "X16rt"       = " -a x16rt -i 26" #X16rt, new in 0.9.1
    "X16rv2"      = " -a x16rv2" #X16rv2, new in 0.14.4
    "X16s"        = " -a x16s -i 24" #X16s
    "X17"         = " -a x17 -i 26" #X17
    "X21s"        = " -a x21s -i 23" #X21s, new in 0.8.3
    "X22i"        = " -a x22i -i 23" #X22i, new in 0.7.2
    "X25x"        = " -a x25x -i 21" #X25x, new in 0.11.0
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --no-watchdog"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "C11"         {$WarmupTime = 60}
            "MTP"         {$WarmupTime = 60}
            "MTPNicehash" {$WarmupTime = 60}
            default       {$WarmupTime = 45}
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands -b 127.0.0.1:$($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            WarmupTime = $WarmupTime
        }
    }
}
