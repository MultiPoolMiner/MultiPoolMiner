using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\wildrig.exe"
$HashSHA256 = "FF32FD93D72480790A5CF3D6E2AEF6CD4A3BCDBDC42BE562CFC04674AFA11D5F"
$Uri = "https://github.com/andru-kun/wildrig-multi/releases/download/0.13.6/wildrig-multi-0.13.6.2-beta.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "40{0:d2}"

$CommandsBaffin = [PSCustomObject]@{
    "aergo"       = " --opencl-threads 2 --opencl-launch 17x0" # new with 0.13.1 beta
    "bcd"         = " --opencl-threads 2 --opencl-launch 19x0"
    "bitcore"     = " --opencl-threads 2 --opencl-launch 17x0" # new with 0.12.1 beta
    "c11"         = " --opencl-threads 2 --opencl-launch 17x0"
    "exosis"      = " --opencl-threads 2 --opencl-launch 18x128" # new with 12.5.1 beta
    "geek"        = " --opencl-threads 2 --opencl-launch 18x128"
    "hex"         = " --opencl-threads 2 --opencl-launch 20x0"
    "hmq1725"     = " --opencl-threads 2 --opencl-launch 20x128"
    "lyra2vc0ban" = " --opencl-threads 1 --opencl-launch 23x0" # new with 0.13.6.2 beta
    "nist5"       = " --opencl-threads 2 --opencl-launch 18x128"
    "phi"         = " --opencl-threads 3 --opencl-launch 19x0"
    "renesis"     = " --opencl-threads 3 --opencl-launch 19x0"
    "skunkhash"   = " --opencl-threads 3 --opencl-launch 17x0" # new with 12.5.1 beta
    "sonoa"       = " --opencl-threads 2 --opencl-launch 17x0"
    "timetravel"  = " --opencl-threads 2 --opencl-launch 17x128"
    "tribus"      = " --opencl-threads 2 --opencl-launch 20x0"
    "x16r"        = " --opencl-threads 2 --opencl-launch 18x0"
    "x16s"        = " --opencl-threads 2 --opencl-launch 18x0"
    "x17"         = " --opencl-threads 2 --opencl-launch 18x0"
    "x18"         = " --opencl-threads 2 --opencl-launch 17x0" # new in 13.0 beta
    "x21s"        = " --opencl-threads 2 --opencl-launch 20x0" # new in 13.4 beta
    "x22i"        = " --opencl-threads 2 --opencl-launch 19x0" # new with 12.5.1 beta
}
$CommandsEllesmere32CU = [PSCustomObject]@{
    "aergo"       = " --opencl-threads 2 --opencl-launch 17x128" # new with 0.13.1 beta
    "bcd"         = " --opencl-threads 2 --opencl-launch 20x0"
    "bitcore"     = " --opencl-threads 2 --opencl-launch 19x0" # new with 0.12.1 beta
    "c11"         = " --opencl-threads 2 --opencl-launch 19x0"
    "dedal"       = " --opencl-threads 2 --opencl-launch 20x0" # new in 13.4 beta
    "exosis"      = " --opencl-threads 3 --opencl-launch 18x128" # new with 12.5.1 beta
    "geek"        = " --opencl-threads 2 --opencl-launch 20x128"
    "hex"         = " --opencl-threads 2 --opencl-launch 22x0"
    "hmq1725"     = " --opencl-threads 2 --opencl-launch 21x128"
    "lyra2vc0ban" = " --opencl-threads 1 --opencl-launch 23x0" # new with 0.13.6.2 beta
    "nist5"       = " --opencl-threads 3 --opencl-launch 18x128"
    "phi"         = " --opencl-threads 3 --opencl-launch 19x0"
    "renesis"     = " --opencl-threads 3 --opencl-launch 19x128"
    "skunkhash"   = " --opencl-threads 3 --opencl-launch 19x0" # new with 12.5.1 beta
    "sonoa"       = " --opencl-threads 2 --opencl-launch 19x0"
    "timetravel"  = " --opencl-threads 2 --opencl-launch 19x128"
    "tribus"      = " --opencl-threads 2 --opencl-launch 21x0"
    "x16r"        = " --opencl-threads 2 --opencl-launch 20x0"
    "x16s"        = " --opencl-threads 2 --opencl-launch 20x0"
    "x17"         = " --opencl-threads 2 --opencl-launch 20x0"
    "x18"         = " --opencl-threads 2 --opencl-launch 19x0" # new in 13.0 beta
    "x21s"        = " --opencl-threads 2 --opencl-launch 20x0" # new in 13.4 beta
    "x22i"        = " --opencl-threads 2 --opencl-launch 19x0" # new with 12.5.1 beta
}
$CommandsEllesmere36CU = [PSCustomObject]@{
    "aergo"       = " --opencl-threads 2 --opencl-launch 17x128" # new with 0.13.1 beta
    "bcd"         = " --opencl-threads 2 --opencl-launch 20x0"
    "bitcore"     = " --opencl-threads 2 --opencl-launch 19x0" # new with 0.12.1 beta
    "c11"         = " --opencl-threads 2 --opencl-launch 19x0"
    "dedal"       = " --opencl-threads 2 --opencl-launch 20x0" # new in 13.4 beta
    "exosis"      = " --opencl-threads 3 --opencl-launch 18x128" # new with 12.5.1 beta
    "geek"        = " --opencl-threads 2 --opencl-launch 20x128"
    "hex"         = " --opencl-threads 2 --opencl-launch 23x0"
    "hmq1725"     = " --opencl-threads 2 --opencl-launch 21x128"
    "lyra2vc0ban" = " --opencl-threads 1 --opencl-launch 23x0" # new with 0.13.6.2 beta
    "nist5"       = " --opencl-threads 3 --opencl-launch 18x128"
    "phi"         = " --opencl-threads 3 --opencl-launch 20x0"
    "renesis"     = " --opencl-threads 3 --opencl-launch 20x128"
    "skunkhash"   = " --opencl-threads 3 --opencl-launch 19x0" # new with 12.5.1 beta
    "sonoa"       = " --opencl-threads 2 --opencl-launch 19x0"
    "timetravel"  = " --opencl-threads 2 --opencl-launch 19x128"
    "tribus"      = " --opencl-threads 2 --opencl-launch 21x0"
    "x16r"        = " --opencl-threads 2 --opencl-launch 20x0"
    "x16s"        = " --opencl-threads 2 --opencl-launch 20x0"
    "x17"         = " --opencl-threads 2 --opencl-launch 20x0"
    "x18"         = " --opencl-threads 2 --opencl-launch 19x0" # new in 13.0 beta
    "x22i"        = " --opencl-threads 2 --opencl-launch 576x0" # new with 12.5.1 beta
}
$CommandsGfx900 = [PSCustomObject]@{
    "aergo"       = " --opencl-threads 2 --opencl-launch 17x128" # new with 0.13.1 beta
    "bcd"         = " --opencl-threads 2 --opencl-launch 20x0"
    "bitcore"     = " --opencl-threads 2 --opencl-launch 19x0" # new with 0.12.1 beta
    "c11"         = " --opencl-threads 2 --opencl-launch 19x0"
    "dedal"       = " --opencl-threads 2 --opencl-launch 20x0" # new in 13.4 beta
    "exosis"      = " --opencl-threads 2 --opencl-launch 18x128" # new with 12.5.1 beta
    "geek"        = " --opencl-threads 2 --opencl-launch 20x128"
    "hex"         = " --opencl-threads 2 --opencl-launch 23x0"
    "hmq1725"     = " --opencl-threads 2 --opencl-launch 21x128"
    "lyra2vc0ban" = " --opencl-threads 1 --opencl-launch 23x0" # new with 0.13.6.2 beta
    "nist5"       = " --opencl-threads 2 --opencl-launch 18x128"
    "phi"         = " --opencl-threads 2 --opencl-launch 20x0"
    "renesis"     = " --opencl-threads 2 --opencl-launch 20x128"
    "skunkhash"   = " --opencl-threads 2 --opencl-launch 19x0" # new with 12.5.1 beta
    "sonoa"       = " --opencl-threads 2 --opencl-launch 19x0"
    "timetravel"  = " --opencl-threads 2 --opencl-launch 19x128"
    "tribus"      = " --opencl-threads 2 --opencl-launch 21x0"
    "x16r"        = " --opencl-threads 2 --opencl-launch 20x0"
    "x16s"        = " --opencl-threads 2 --opencl-launch 20x0"
    "x17"         = " --opencl-threads 2 --opencl-launch 20x0"
    "x18"         = " --opencl-threads 2 --opencl-launch 19x0" # new in 13.0 beta
    "x21s"        = " --opencl-threads 2 --opencl-launch 20x0" # new in 13.4 beta
    "x22i"        = " --opencl-threads 2 --opencl-launch 576x0" # new with 12.5.1 beta
}
$CommonCommands = " --donate-level 1"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model | Where-Object {$_.OpenCL.Name -match "^Baffin.*|^Ellesmere.*|^Fiji.*|^gfx900.*|^Tonga.*"})
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    

    if ($Config.CreateMinerInstancePerDeviceModel) {
        Switch (($Miner_Device | Select-Object -First 1 -ExpandProperty OpenCl).Name) {
            "Ellesmere" {$Commands = Get-Variable $("CommandsEllesmere$(($Miner_Device | Select-Object -First 1 -ExpandProperty OpenCl).MaxComputeUnits)CU") -ValueOnly -ErrorAction SilentlyContinue}
            "gfx900" {$Commands = $CommandsGfx900}
            default  {$Commands = $CommandsBaffin}
        }
    }
    else {
        $Commands = $CommandsGfx900
    }

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
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
                Arguments          = ("--algo=$_ --api-port=$Miner_Port --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$(if($Config.CreateMinerInstancePerDeviceModel -and @($Devices | Select-Object Model_Norm -Unique).count -gt 1){" --multiple-instance"})$($Commands.$_)$CommonCommands --opencl-platform=$($Miner_Device.PlatformId | Sort-Object -Unique) --opencl-devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API                = "XmRig"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
                BenchmarkIntervals = $BenchmarkIntervals
            }
        }
    }
}
