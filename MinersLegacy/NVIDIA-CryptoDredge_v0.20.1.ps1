using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\CryptoDredge.exe"
$ManualUri = "https://github.com/technobyl/CryptoDredge"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 9.2 or higher
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.00"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

if ($CUDAVersion -lt [System.Version]("10.1.0")) {
    $HashSHA256 = "098C1E2056D21B8C9B15F5F9F87E8C06FD758AF12A8E90CB04E3100AB919CAB4"
    $Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.20.1/CryptoDredge_0.20.1_cuda_9.2_windows.zip"
}
else {
    $HashSHA256 = "21B81A2D62B9D22564A5520D5E1F5F356B04CE850D32957BF893F119FF1ADA7B"
    $Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.20.1/CryptoDredge_0.20.1_cuda_10.1_windows.zip"
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "aeon";        MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Aeon, new in 0.9 (CryptoNight-Lite algorithm)
        [PSCustomObject]@{Algorithm = "aeternity";   MinMemGB = 3; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #Cuckoo29, new in 0.17.0
        [PSCustomObject]@{Algorithm = "allium";      MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Allium
        [PSCustomObject]@{Algorithm = "argon2d250";  MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Argon2CRDS, new in 19.1
        [PSCustomObject]@{Algorithm = "argon2d4096"; MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Argon2UIS, new in 19.1
        [PSCustomObject]@{Algorithm = "argon2d-dyn"; MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Argon2dDYN
        [PSCustomObject]@{Algorithm = "bcd";         MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #BitcoinDiamond, new in 0.9.4
        [PSCustomObject]@{Algorithm = "bitcore";     MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Timetravel10
        [PSCustomObject]@{Algorithm = "cnfast2";     MinMemGB = 2; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #CryptonightFast2, new in 16.2
        [PSCustomObject]@{Algorithm = "cngpu";       MinMemGB = 2; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #CryptonightGpu, new in 0.17.0
        [PSCustomObject]@{Algorithm = "cnhaven";     MinMemGB = 4; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #CryptonightHeavyHaven, new in 0.9.1
        [PSCustomObject]@{Algorithm = "cnheavy";     MinMemGB = 4; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #CryptonightHeavy, new in 0.9
        [PSCustomObject]@{Algorithm = "cnsaber";     MinMemGB = 4; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #CryptonightHeavyTube (BitTube), new in 0.9.2
        [PSCustomObject]@{Algorithm = "cnturtle";    MinMemGB = 2; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #CryptonightTurtle, new in 0.17.0
        [PSCustomObject]@{Algorithm = "cnv8";        MinMemGB = 2; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #CyptonightV8, new in 0.9.3
        [PSCustomObject]@{Algorithm = "cuckaroo29";  MinMemGB = 6; IntervalMultiplier = 1; Fee = 1; Params = " -i 5"} #Cuckaroo29, new in 0.17.0
        [PSCustomObject]@{Algorithm = "hmq1725";     MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #HMQ1725, new in 0.10.0
        [PSCustomObject]@{Algorithm = "lyra2rev3";   MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Lyra2REv3, new in 0.14.0 
        [PSCustomObject]@{Algorithm = "lyra2vc0ban"; MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Lyra2vc0banHash, new in 0.13.0
        [PSCustomObject]@{Algorithm = "lyra2z";      MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Lyra2z
        [PSCustomObject]@{Algorithm = "lyra2zz";     MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Lyra2zz, new in 0.16.0 
        [PSCustomObject]@{Algorithm = "mtp";         MinMemGB = 5; IntervalMultiplier = 1; Fee = 2; Params = ""} #MTP, new with 0.15.0
        [PSCustomObject]@{Algorithm = "neoscrypt";   MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #NeoScrypt
        [PSCustomObject]@{Algorithm = "phi2";        MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #PHI2
        [PSCustomObject]@{Algorithm = "pipe" ;       MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Pipe, new in 12.0
        [PSCustomObject]@{Algorithm = "skunk";       MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Skunk
        [PSCustomObject]@{Algorithm = "tribus" ;     MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #Tribus, new with 0.8
        [PSCustomObject]@{Algorithm = "x16r";        MinMemGB = 1; IntervalMultiplier = 5; Fee = 1; Params = ""} #X16R, new in 0.11.0
        [PSCustomObject]@{Algorithm = "x16rt";       MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #X16rt, new in 0.16.0
        [PSCustomObject]@{Algorithm = "x16s";        MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #X16S, new in 0.11.0
        [PSCustomObject]@{Algorithm = "x17";         MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #X17, new in 0.9.5
        [PSCustomObject]@{Algorithm = "x21s";        MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #X21s, new in 0.13.0
        [PSCustomObject]@{Algorithm = "x22i";        MinMemGB = 1; IntervalMultiplier = 1; Fee = 1; Params = ""} #X22i, new in 0.9.6
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --no-watchdog --no-crashreport $(if (-not $Config.ShowMinerWindow) {" --no-color"})"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB
        $IntervalMultiplier = $_.IntervalMultiplier
        $Fee = $_.Fee
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $_.Parameters $Miner_Device.Type_Vendor_Index
            }

            [PSCustomObject]@{
                Name               = $Miner_Name
                BaseName           = $Miner_BaseName
                Version            = $Miner_Version
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("--api-type ccminer-tcp --api-bind 127.0.0.1:$($Miner_Port) -a $Algorithm -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$Parameters$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API                = "Ccminer"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = [PSCustomObject]@{$Algorithm_Norm = $Fee / 100}
                IntervalMultiplier = $IntervalMultiplier
                WarmupTime         = 45 #seconds
            }
        }
    }
}