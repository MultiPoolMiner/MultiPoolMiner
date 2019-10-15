using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\wildrig.exe"
$HashSHA256 = "3A23A297C5EB95FEBB44B0E89CB1929AFB69AF0D35D4FCDE737558D35A66DB66"
$Uri = "https://github.com/andru-kun/wildrig-multi/releases/download/0.19.3/wildrig-multi-windows-0.19.3-beta.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject]@{
    "aergo"          = " --algo=aergo"
    "bcd"            = " --algo=bcd"
    # "bitcore"      = " --algo=bitcore"; Same as Timetravel10
    "blake2b-btcc"   = " --algo=blake2b-btcc" # new in 0.17.5 preview 8
    "blake2b-glt"    = " --algo=blake2b-glt" # new in 0.17.5 preview 8
    "bmw512"         = " --algo=bmw512" # new in 0.15.4 preview 8
    "c11"            = " --algo=c11"
    "dedal"          = " --algo=dedal"
    "exosis"         = " --algo=exosis"
    "geek"           = " --algo=geek"
    "glt-astralhash" = " --algo=glt-astralhash"
    "glt-globalhash" = " --algo=glt-globalhash" # new in 0.18.0
    "glt-jeonghash"  = " --algo=glt-jeonghash"
    "glt-padihash"   = " --algo=glt-padihash"
    "glt-pawelhash"  = " --algo=glt-pawelhash"
    "hex"            = " --algo=hex"
    "hmq1725"        = " --algo=hmq1725"
    "honeycomb"      = " --algo=honeycomb" # new in 0.16.0
    "lyra2v3"        = " --algo=lyra2v3"
    "lyra2vc0ban"    = " --algo=lyra2vc0ban"
    "phi"            = " --algo=phi"
    "polytimos"      = " --algo=polytimos"
    "rainforest"     = " --algo=rainforest"
    "renesis"        = " --algo=renesis"
    "sha256q"        = " --algo=sha256q"
    "sha256t"        = " --algo=sha256t"
    "skein2"         = " --algo=skein2" # new in 0.17.6
    #"skunk"          = " --algo=skunkhash" #Unprofitable
    "sonoa"          = " --algo=sonoa"
    "timetravel"     = " --algo=timetravel"
    "timetravel10"   = " --algo=timetravel10"
    "tribus"         = " --algo=tribus"
    "wildkeccak"     = " --algo=wildkeccak"
    "x16r"           = " --algo=x16r"
    "x16rt"          = " --algo=x16rt"
    "x16rv2"         = " --algo=x16r" # new in 0.19.2
    "x16s"           = " --algo=x16s"
    "x17"            = " --algo=x17"
    "x18"            = " --algo=x18"
    "x20r"           = " --algo=x20r"
    "x21s"           = " --algo=x21s"
    "x22i"           = " --algo=x22i"
    "x25x"           = " --algo=x25x" # new in 0.17.0
    "xevan"          = " --algo=xevan"
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --opencl-threads auto --opencl-launch auto --multiple-instance"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        #Optionally disable dev fee mining, cannot be done for Honeycomb or Wildkeccak algorithm
        if ($null -eq $Miner_Config) {$Miner_Config = [PSCustomObject]@{DisableDevFeeMining = $Config.DisableDevFeeMining}}
        if ($Algorithm_Norm -notmatch "Honeycomb|Wildkeccak" -and $Miner_Config.DisableDevFeeMining) {
            $NoFee = "--donate-level 0"
            $Miner_Fees = [PSCustomObject]@{$Algorithm_Norm = 0}
        }
        else {
            $NoFee = ""
            $Miner_Fees = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
        }

        Switch ($Algorithm_Norm) {
            "C11"   {$WarmupTime = 60}
            default {$WarmupTime = $(if (@($Device | Where-Object {$_.Type -eq "CPU" -or ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge 2})) {30} else {60})}
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands --api-port=$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass) --opencl-platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --opencl-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Slot}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "XmRig"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = $Miner_Fees
            WarmupTime = $WarmupTime
        }
    }
}
