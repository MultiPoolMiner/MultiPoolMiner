using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\t-rex.exe"
$ManualUri = "https://bitcointalk.org/index.php?topic=4432704.0"
$HashSHA256 = "45e31955f504618e87c54f3f3a3d1d42b94d3e35ddda967688d68e888a9ee897"
$Uri = "https://github.com/Minerx117/miner-binaries/releases/download/0.12.2b/t-rex-0.12.2b-win-cuda10.0.7z"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        "astralhash" = "" #GltAstralHash, new in 0.8.6
        "balloon"    = "" #Balloon, new in 0.6.2
        "bcd"        = "" #BitcoinDiamond, new in 0.6.5
        "bitcore"    = "" #Timetravel10 and Bitcore are technically the same
        "c11"        = "" #C11
        "geek"       = "" #Geek, new in 0.8.0
        # "hmq1725"    = "" #Hmq1725, new in 0.6.4; NVIDIA-CryptoDredge_v0.20.2 is faster
        "honeycomb"  = "" #Honeycomb, new in 12.0
        "jeonghash"  = "" #GltJeongHash, new in 0.8.6
        "lyra2z"     = "" #Lyra2z
        "mtp"        = "" #MTP, new in 0.10.2
        "padihash"   = "" #GltPadilHash, new in 0.8.6
        "pawelhash"  = "" #GltPawelHash, new in 0.8.6
        "phi"        = "" #Phi
        "polytimos"  = "" #Polytimos, new in 0.6.3
        "sha256q"    = "" #Sha256q, new in 0.9.1
        "sha256t"    = "" #Sha256t
        "skunk"      = "" #Skunk, new in 0.6.3
        "sonoa"      = "" #Sonoa, new in 0.6.1
        "timetravel" = "" #Timetravel
        "tribus"     = "" #Tribus
        "x16r"       = "" #X16r
        "x16rt"      = "" #X16rt, new in 0.9.1
        "x16s"       = "" #X16s
        "x17"        = "" #X17
        "x21s"       = "" #X21s, new in 0.8.3
        "x22i"       = "" #X22i, new in 0.7.2
        "x25x"       = "" #X25x, new in 0.11.0
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --no-watchdog"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
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

        Switch ($Algorithm_Norm) {
            "X16R"  {$IntervalMultiplier = 5}
            "X16Rt" {$IntervalMultiplier = 3}
            default {$IntervalMultiplier = 1}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            BaseName           = $Miner_BaseName
            Version            = $Miner_Version
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("-b 127.0.0.1:$($Miner_Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Ccminer"
            Port               = $Miner_Port
            URI                = $Uri
            Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            IntervalMultiplier = $IntervalMultiplier
        }
    }
}
