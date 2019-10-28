using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\wildrig.exe"
$HashSHA256 = "676B8C53DE0A841EFDFFB0FBC40A678A5F4E06FFD5AB87AE4E7A0CABE126B572"
$Uri = "https://github.com/andru-kun/wildrig-multi/releases/download/0.20.0/wildrig-multi-windows-0.20.0.2.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) { $Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*" }

$Commands = [PSCustomObject]@{ 
    "Aergo"          = " --algo=aergo"
    "Bcd"            = " --algo=bcd"
    # "bitcore"      = " --algo=bitcore"; Same as Timetravel10
    "Blake2b-Btcc"   = " --algo=blake2b-btcc" # new in 0.17.5 preview 8
    "blake2b-Glt"    = " --algo=blake2b-glt" # new in 0.17.5 preview 8
    "Bmw512"         = " --algo=bmw512" # new in 0.15.4 preview 8
    "C11"            = " --algo=c11"
    "Dedal"          = " --algo=dedal"
    "Exosis"         = " --algo=exosis"
    "Geek"           = " --algo=geek"
    "Glt-Astralhash" = " --algo=glt-astralhash"
    "Glt-Globalhash" = " --algo=glt-globalhash" # new in 0.18.0
    "Glt-Jeonghash"  = " --algo=glt-jeonghash"
    "Glt-Padihash"   = " --algo=glt-padihash"
    "Glt-Pawelhash"  = " --algo=glt-pawelhash"
    "Hex"            = " --algo=hex"
    "Hmq1725"        = " --algo=hmq1725"
    "Honeycomb"      = " --algo=honeycomb" # new in 0.16.0
    "Lyra2v3"        = " --algo=lyra2v3"
    "Lyra2vc0ban"    = " --algo=lyra2vc0ban"
    "Mtp"            = " --algo=mtp" # new in 0.20.0
    "MtpTcr"         = " --algo=mtp-tcr" # new in 0.20.0
    "Phi"            = " --algo=phi"
    "Polytimos"      = " --algo=polytimos"
    "Rainforest"     = " --algo=rainforest"
    "Renesis"        = " --algo=renesis"
    "Sha256q"        = " --algo=sha256q"
    "Sha256t"        = " --algo=sha256t"
    "Skein2"         = " --algo=skein2" # new in 0.17.6
    #"skunk"          = " --algo=skunkhash" #Unprofitable
    "Sonoa"          = " --algo=sonoa"
    "Timetravel"     = " --algo=timetravel"
    "Timetravel10"   = " --algo=timetravel10"
    "Tribus"         = " --algo=tribus"
    "Wildkeccak"     = " --algo=wildkeccak"
    "X16r"           = " --algo=x16r"
    "X16rt"          = " --algo=x16rt"
    "X16rv2"         = " --algo=x16rv2" # new in 0.19.2
    "X16s"           = " --algo=x16s"
    "X17"            = " --algo=x17"
    "X18"            = " --algo=x18"
    "X20r"           = " --algo=x20r"
    "X21s"           = " --algo=x21s"
    "X22i"           = " --algo=x22i"
    "X25x"           = " --algo=x25x" # new in 0.17.0
    "Xevan"          = " --algo=xevan"
}
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " --opencl-threads auto --opencl-launch auto --multiple-instance --no-adl" }

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")
$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_; $_ } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> } | ForEach-Object { 
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object { $Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm" }) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        #Optionally disable dev fee mining, cannot be done for Honeycomb or Wildkeccak algorithm
        if ($null -eq $Miner_Config) { $Miner_Config = [PSCustomObject]@{ DisableDevFeeMining = $Config.DisableDevFeeMining } }
        if ($Algorithm_Norm -notmatch "Honeycomb|Wildkeccak" -and $Miner_Config.DisableDevFeeMining) { 
            $NoFee = "--donate-level 0"
            $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 0 }
        }
        else { 
            $NoFee = ""
            $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 2 / 100 }
        }

        Switch ($Algorithm_Norm) { 
            "C11"   { $WarmupTime = 60 }
            default { $WarmupTime = $(if (@($Device | Where-Object { $_.Type -eq "CPU" -or ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge 2 })) { 30 } else { 60 }) }
        }

        [PSCustomObject]@{ 
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands --api-port=$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass) --opencl-platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --opencl-devices=$(($Miner_Device | ForEach-Object { '{0:x}' -f $_.Type_Vendor_Slot }) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
            API        = "XmRig"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = $Miner_Fees
            WarmupTime = $WarmupTime
        }
    }
}
