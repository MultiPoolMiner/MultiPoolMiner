using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\z-enemy.exe"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 9.2.00 or higher
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

if ($CUDAVersion -lt [System.Version]("10.0.0")) {
    $HashSHA256 = "AE09498A48CF075153CCA06BB1597CB1237BFB8FD3668743387A055767D692BD"
    $Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Zenemy/z-enemy-2.1-cuda9.2.zip"
}
else {
    $HashSHA256 = "66C636BD6B34E5C803748D9224C8448F8EEB4167A46688D04E6112C24C69947D"
    $Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Zenemy/z-enemy-2.1-cuda10.0.zip"
}

$Commands = [PSCustomObject]@{
    "aergo"      = " --algo=aergo" #Aergo, new in 1.11
    "bitcore"    = " --algo=bitcore" #Timetravel10 and Bitcore are technically the same
    "bcd"        = " --algo=bcd" #Bitcoin Diamond, new in 1.20
    "c11"        = " --algo=c11 --intensity=26 --statsavg 10" #C11, new in 1.11
    "hex"        = " --algo=hex" #Hex
    "phi"        = " --algo=phi_" #PHI
    "phi2"       = " --algo=phi2" #Phi2
    "poly"       = " --algo=poly" #Polytimos
    "skunk"      = " --algo=skunk" #Skunk, new in 1.11
    "sonoa"      = " --algo=sonoa" #SONOA, new in 1.12
    "timetravel" = " --algo=timetravel" #Timetravel
    "tribus"     = " --algo=tribus" #Tribus, new in 1.10
    "x16r"       = " --algo=x16r --statsavg=50" #Raven, number of samples used to compute hashrate (default: 30) 
    "x16s"       = " --algo=x16s" #Pigeon
    "x17"        = " --algo=x17" #X17
    "xevan"      = " --algo=xevan --intensity=26" #Xevan, new in 1.09a
}
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Commands | Add-Member $_ $($Miner_Config.Commands.$_) -Force}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

        #Get commands for active miner devices
        $Command = Get-CommandPerDevice -Command $Commands.$_ -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

        Switch ($Algorithm_Norm) {
            "C11"    {$WarmupTime = 60}
            "Xevan"  {$WarmupTime = 60}
            "X16R"   {$WarmupTime = 60}
            default  {$WarmupTime = 45}
        }

        [PSCustomObject]@{
            Name       = $Miner_Name
            BaseName   = $Miner_BaseName
            Version    = $Miner_Version
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = ("$Command$CommonCommands --api-bind=127.0.0.1:$($Miner_Port) --api-bind-http=0 --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass) --devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Ccminer"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            WarmupTime = $WarmupTime #seconds
        }
    } 
}
