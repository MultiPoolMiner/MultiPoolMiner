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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
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

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject]@{
        "aergo"      = "" #Aergo, new in 1.11
        "bitcore"    = "" #Timetravel10 and Bitcore are technically the same
        "bcd"        = "" #Bitcoin Diamond, new in 1.20
        "c11"        = "" #C11, new in 1.11
        "hex"        = "" #Hex
        "phi"        = "" #PHI
        "phi2"       = "" #Phi2
        "poly"       = "" #Polytimos
        "skunk"      = "" #Skunk, new in 1.11
        "sonoa"      = "" #SONOA, new in 1.12
        "timetravel" = "" #Timetravel
        "tribus"     = "" #Tribus, new in 1.10
        "x16r"       = " --statsavg=50" #Raven, number of samples used to compute hashrate (default: 30) 
        "x16s"       = "" #Pigeon
        "x17"        = "" #X17
        "xevan"      = "" #Xevan, new in 1.09a
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = ""}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
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
            "C11"   {$IntervalMultiplier = 1; $WarmupTime = 60}
            "X16R"  {$IntervalMultiplier = 5; $WarmupTime = 30}
            default {$IntervalMultiplier = 1; $WarmupTime = 30}
        }

        [PSCustomObject]@{
            Name               = $Miner_Name
            BaseName           = $Miner_BaseName
            Version            = $Miner_Version
            DeviceName         = $Miner_Device.Name
            Path               = $Path
            HashSHA256         = $HashSHA256
            Arguments          = ("--algo=$_ --api-bind=127.0.0.1:$($Miner_Port) --api-bind-http=0 --url=$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user=$($Pools.$Algorithm_Norm.User) --pass=$($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters --devices=$(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
            HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API                = "Ccminer"
            Port               = $Miner_Port
            URI                = $Uri
            Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            IntervalMultiplier = $IntervalMultiplier
            WarmupTime         = $WarmupTime #seconds
        }
    } 
}
