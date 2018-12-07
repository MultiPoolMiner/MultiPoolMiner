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
$Port = "40{0:d2}"

# Miner requires CUDA 9.2.00 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

if ($DriverVersion -lt [System.Version]("10.0.0")) {
    $HashSHA256 = "1B30616CF34997496291E66244B718221142EE4CE4B2DD39F408616DA7613369"
    $Uri = "https://github.com/trexminer/T-Rex/releases/download/0.8.5/t-rex-0.8.5-win-cuda9.1.zip"
}
else {
    $HashSHA256 = "00AFD119A9DD7B8C48E482AC70E1F27FBEFF70A0D1A9204252602F7CD901CFCA"
    $Uri = "https://github.com/trexminer/T-Rex/releases/download/0.8.5/t-rex-0.8.5-win-cuda10.0.zip"
}

$Commands = [PSCustomObject]@{
    "balloon"    = "" #Balloon, New in 0.6.2
    "bcd"        = "" #BitcoinDiamond, New in 0.6.5
    "bitcore"    = "" #Bitcore, New in 0.6.1
    "c11"        = "" #C11
    "dedal"      = "" #Dedal, new in 0.8.2
    "geek"       = "" #Geek, new in 0.8.0
    "hmq1725"    = "" #Hmq1725, New in 0.6.4
    "lyra2z"     = "" #Lyra2z
    "phi"        = "" #Phi
    "polytimos"  = "" #Polytimos, New in 0.6.3
    "renesis"    = "" #Renesis
    "sha256t"    = "" #Sha256t
    "skunk"      = "" #Skunk, New in 0.6.3
    "sonoa"      = "" #Sonoa, New in 0.6.1
    "timetravel" = "" #Timetravel
    "tribus"     = "" #Tribus
    "x16r"       = "" #X16r
    "x16s"       = "" #X16s
    "x17"        = "" #X17
    "x21s"       = "" #X21s, new in 0.8.3
    "x22i"       = "" #X22i, new in 0.7.2
}
$CommonCommands = ""

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = "$Name-$($Miner_Device.count)x$($Miner_Device.Model_Norm | Sort-Object -unique)"		
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
            Arguments          = ("-b 127.0.0.1:$($Miner_Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Ccminer"
            Port               = $Miner_Port
            URI                = $Uri
            Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            BenchmarkIntervals = $BenchmarkIntervals
        }
    }
}