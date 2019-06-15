using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\wildrig.exe"
$HashSHA256 = "1BEB7005D14E8AB6214A281191462783FD22BE07E2E6B77F303242EA7CE76F56"
$Uri = "https://github.com/andru-kun/wildrig-multi/releases/download/0.17.5/wildrig-multi-windows-0.17.5-beta.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        "aergo"          = " --opencl-threads auto --opencl-launch auto"
        "bcd"            = " --opencl-threads auto --opencl-launch auto"
        # "bitcore"      = " --opencl-threads auto --opencl-launch auto"; Same as Timetravel10
        "blake2b-btcc"   = " --opencl-threads auto --opencl-launch auto" # new in 0.17.5 preview 8
        "blake2b-glt"    = " --opencl-threads auto --opencl-launch auto" # new in 0.17.5 preview 8
        "bmw512"         = " --opencl-threads auto --opencl-launch auto" # new in 0.15.4 preview 8
        "c11"            = " --opencl-threads auto --opencl-launch auto"
        "dedal"          = " --opencl-threads auto --opencl-launch auto"
        "exosis"         = " --opencl-threads auto --opencl-launch auto"
        "geek"           = " --opencl-threads auto --opencl-launch auto"
        "glt-astralhash" = " --opencl-threads auto --opencl-launch auto"
        "glt-jeonghash"  = " --opencl-threads auto --opencl-launch auto"
        "glt-padihash"   = " --opencl-threads auto --opencl-launch auto"
        "glt-pawelhash"  = " --opencl-threads auto --opencl-launch auto"
        "hex"            = " --opencl-threads auto --opencl-launch auto"
        "hmq1725"        = " --opencl-threads auto --opencl-launch auto"
        "honeycomb"      = " --opencl-threads auto --opencl-launch auto"
        "lyra2v3"        = " --opencl-threads auto --opencl-launch auto"
        "lyra2vc0ban"    = " --opencl-threads auto --opencl-launch auto"
        "phi"            = " --opencl-threads auto --opencl-launch auto"
        "polytimos"      = " --opencl-threads auto --opencl-launch auto"
        "rainforest"     = " --opencl-threads auto --opencl-launch auto"
        "renesis"        = " --opencl-threads auto --opencl-launch auto"
        "sha256q"        = " --opencl-threads auto --opencl-launch auto"
        "sha256t"        = " --opencl-threads auto --opencl-launch auto"
        "skunkhash"      = " --opencl-threads auto --opencl-launch auto"
        "sonoa"          = " --opencl-threads auto --opencl-launch auto"
        "timetravel"     = " --opencl-threads auto --opencl-launch auto"
        "timetravel10"   = " --opencl-threads auto --opencl-launch auto"
        "tribus"         = " --opencl-threads auto --opencl-launch auto"
        "wildkeccak"     = " --opencl-threads auto --opencl-launch auto"
        "x16r"           = " --opencl-threads auto --opencl-launch auto"
        "x16rt"          = " --opencl-threads auto --opencl-launch auto"
        "x16s"           = " --opencl-threads auto --opencl-launch auto"
        "x17"            = " --opencl-threads auto --opencl-launch auto"
        "x18"            = " --opencl-threads auto --opencl-launch auto"
        "x20r"           = " --opencl-threads auto --opencl-launch auto"
        "x21s"           = " --opencl-threads auto --opencl-launch auto"
        "x22i"           = " --opencl-threads auto --opencl-launch auto"
        "x25x"           = " --opencl-threads auto --opencl-launch auto" # new in 0.17.0
        "xevan"          = " --opencl-threads auto --opencl-launch auto"
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --donate-level 1"}

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
