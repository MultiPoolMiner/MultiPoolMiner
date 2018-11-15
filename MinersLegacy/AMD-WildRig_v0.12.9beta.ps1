using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\wildrig.exe"
$HashSHA256 = "9DC9BF203AC48FBB99540DC919985203587F0728D93AF3EE6653E854030A90E0"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/WildRig/wildrig-multi-0.12.9-beta.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject]@{
    "aergo"      = " --opencl-threads=3 --opencl-launch=19x128"
    "bcd"        = " --opencl-threads=3 --opencl-launch=19x128"
    "bitcore"    = " --opencl-threads=3 --opencl-launch=16x128" # new with 0.12.1 beta
    "c11"        = " --opencl-threads=3 --opencl-launch=17x128"
    "exosis"     = " --opencl-threads=3 --opencl-launch=18x128" # new with 12.5.1 beta
    "geek"       = " --opencl-threads=3 --opencl-launch=18x128"
    "hex"        = " --opencl-threads=3 --opencl-launch=18x0"
    "hmq1725"    = " --opencl-threads=3 --opencl-launch=18x128"
    "nist5"      = " --opencl-threads=3 --opencl-launch=18x128"
    "phi"        = " --opencl-threads=3 --opencl-launch=18x128"
    "renesis"    = " --opencl-threads=3 --opencl-launch=21x128"
    "skunkhash"  = " --opencl-threads=3 --opencl-launch=17x128" # new with 12.5.1 beta
    "sonoa"      = " --opencl-threads=3 --opencl-launch=19x128"
    "timetravel" = " --opencl-threads=3 --opencl-launch=18x128"
    "tribus"     = " --opencl-threads=3 --opencl-launch=20x0"
    "x16r"       = " --opencl-threads=3 --opencl-launch=18x128"
    "x16s"       = " --opencl-threads=3 --opencl-launch=18x128"
    "x17"        = " --opencl-threads=3 --opencl-launch=20x0"
    "x22i"       = " --opencl-threads=3 --opencl-launch=17x128" # new with 12.5.1 beta
}
$CommonCommands = " --donate-level 1"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_;"$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        #Get commands for active miner devices
        $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "X16R"  {$BenchmarkIntervals = 5}
            default {$BenchmarkIntervals = 1}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("--algo=$_ --api-port=$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$CommonCommands --opencl-platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --opencl-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "XmRig"
            Port               = $Miner_Port
            URI                = $Uri
            Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            BenchmarkIntervals = $BenchmarkIntervals
        }
    }
}
