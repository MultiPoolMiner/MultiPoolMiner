﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\wildrig.exe"
$HashSHA256 = "061869D85BF03E7716B305DA723482ADE43D13FBFA85BEBD8F4D6A9D4692A1CD"
$Uri = "https://github.com/andru-kun/wildrig-multi/releases/download/0.17.8/wildrig-multi-windows-0.17.8-beta.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        "aergo"          = ""
        "bcd"            = ""
        # "bitcore"      = ""; Same as Timetravel10
        "blake2b-btcc"   = "" # new in 0.17.5 preview 8
        "blake2b-glt"    = "" # new in 0.17.5 preview 8
        "bmw512"         = "" # new in 0.15.4 preview 8
        "c11"            = ""
        "dedal"          = ""
        "exosis"         = ""
        "geek"           = ""
        "glt-astralhash" = ""
        "glt-jeonghash"  = ""
        "glt-padihash"   = ""
        "glt-pawelhash"  = ""
        "hex"            = ""
        "hmq1725"        = ""
        "honeycomb"      = "" # new in 16.0
        "lyra2v3"        = ""
        "lyra2vc0ban"    = ""
        "phi"            = ""
        "polytimos"      = ""
        "rainforest"     = ""
        "renesis"        = ""
        "sha256q"        = ""
        "sha256t"        = ""
        "skein2"         = "" # new in 0.17.6
        "skunkhash"      = ""
        "sonoa"          = ""
        "timetravel"     = ""
        "timetravel10"   = ""
        "tribus"         = ""
        "wildkeccak"     = ""
        "x16r"           = ""
        "x16rt"          = ""
        "x16s"           = ""
        "x17"            = ""
        "x18"            = ""
        "x20r"           = ""
        "x21s"           = ""
        "x22i"           = ""
        "x25x"           = "" # new in 0.17.0
        "xevan"          = ""
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --opencl-threads auto --opencl-launch auto --donate-level 1"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model | Where-Object {$_.Model_Norm -match "^Baffin.*|^Ellesmere.*|^Fiji.*|^gfx804.*|^gfx900.*|^Tonga.*"})
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

        Switch ($Algorithm_Norm) {
            "X16R"  {$IntervalMultiplier = 5}
            default {$IntervalMultiplier = 1}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            BaseName           = $Miner_BaseName
            Version            = $Miner_Version
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("--algo=$_ --api-port=$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$(if($Config.CreateMinerInstancePerDeviceModel -and @($Devices | Select-Object Model_Norm -Unique).count -gt 1){" --multiple-instance"})$Parameters$CommonParameters --opencl-platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --opencl-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.PCIBus_Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "XmRig"
            Port               = $Miner_Port
            URI                = $Uri
            Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            IntervalMultiplier = $IntervalMultiplier
            WarmupTime         = $(if (@($Device | Where-Object {$_.Type -eq "CPU" -or ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge 2})) {30} else {60})
        }
    }
}
