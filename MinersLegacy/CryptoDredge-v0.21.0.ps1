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

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
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
    $HashSHA256 = "51358D2F76494AB33D813BA639AEAF1023D33EC55B3350E26C3763C7BD684B8A"
    $Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.21.0/CryptoDredge_0.21.0_cuda_9.2_windows.zip"
}
else {
    $HashSHA256 = "8FA9C200F25691B74BA29929D3148DDD70ED909461CBCE99A2A1E4EA1A7E804E"
    $Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.21.0/CryptoDredge_0.21.0_cuda_10.1_windows.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "aeon";        MinMemGB = 1; Fee = 1; Command = " --algo aeon"} #Aeon, new in 0.9 (CryptoNight-Lite algorithm)
#    [PSCustomObject]@{Algorithm = "aeternity";   MinMemGB = 3; Fee = 1; Command = " --algo aeternity --intensity 5"} #Cuckoo29, new in 0.17.0, reported API value too small
    [PSCustomObject]@{Algorithm = "allium";      MinMemGB = 1; Fee = 1; Command = " --algo allium"} #Allium
    [PSCustomObject]@{Algorithm = "argon2d250";  MinMemGB = 1; Fee = 1; Command = " --algo argon2d250"} #Argon2CRDS, new in 19.1
    [PSCustomObject]@{Algorithm = "argon2d4096"; MinMemGB = 1; Fee = 1; Command = " --algo argon2d4096"} #Argon2UIS, new in 19.1
    [PSCustomObject]@{Algorithm = "argon2d-dyn"; MinMemGB = 1; Fee = 1; Command = " --algo argon2d-dyn"} #Argon2dDYN
    [PSCustomObject]@{Algorithm = "argon2d-nim"; MinMemGB = 1; Fee = 1; Command = " --algo argon2d-nim"} #Argon2d-nim, new in 21.0
    [PSCustomObject]@{Algorithm = "bcd";         MinMemGB = 1; Fee = 1; Command = " --algo bcd"} #BitcoinDiamond, new in 0.9.4
    [PSCustomObject]@{Algorithm = "bitcore";     MinMemGB = 1; Fee = 1; Command = " --algo bitcore"} #Timetravel10
    [PSCustomObject]@{Algorithm = "chukwa";      MinMemGB = 2; Fee = 1; Command = " --algo chukwa --intensity 5"} #Chukwa, new in 21.0
    [PSCustomObject]@{Algorithm = "chukwa-wrkz"; MinMemGB = 2; Fee = 1; Command = " --algo chukwa-wrkz --intensity 5"} #Chukwa-wrkz, new in 21.0
    [PSCustomObject]@{Algorithm = "cnconceal";   MinMemGB = 2; Fee = 1; Command = " --algo cnconceal --intensity 5"} #CryptonightConmceal, new in 21.0
    [PSCustomObject]@{Algorithm = "cnfast2";     MinMemGB = 2; Fee = 1; Command = " --algo cnfast2 --intensity 5"} #CryptonightFast2, new in 16.2
    [PSCustomObject]@{Algorithm = "cngpu";       MinMemGB = 2; Fee = 1; Command = " --algo cngpu --intensity 5"} #CryptonightGpu, new in 0.17.0
    [PSCustomObject]@{Algorithm = "cnhaven";     MinMemGB = 4; Fee = 1; Command = " --algo cnhaven --intensity 5"} #CryptonightHeavyHaven, new in 0.9.1
    [PSCustomObject]@{Algorithm = "cnheavy";     MinMemGB = 4; Fee = 1; Command = " --algo cnheavy --intensity 5"} #CryptonightHeavy, new in 0.9
    [PSCustomObject]@{Algorithm = "cnsaber";     MinMemGB = 4; Fee = 1; Command = " --algo cnsaber --intensity 5"} #CryptonightHeavyTube (BitTube), new in 0.9.2
    [PSCustomObject]@{Algorithm = "cnturtle";    MinMemGB = 2; Fee = 1; Command = " --algo cnturtle --intensity 5"} #CryptonightTurtle, new in 0.17.0
    [PSCustomObject]@{Algorithm = "cnv8";        MinMemGB = 2; Fee = 1; Command = " --algo cnv8 --intensity 5"} #CyptonightV8, new in 0.9.3
#    [PSCustomObject]@{Algorithm = "cuckaroo29";  MinMemGB = 6; Fee = 1; Command = " --algo cuckaroo29 --intensity 5"} #Cuckaroo29, new in 0.17.0; reported API value too small
    [PSCustomObject]@{Algorithm = "hmq1725";     MinMemGB = 1; Fee = 1; Command = " --algo hmq1725"} #HMQ1725, new in 0.10.0
    [PSCustomObject]@{Algorithm = "lyra2rev3";   MinMemGB = 1; Fee = 1; Command = " --algo lyra2rev3"} #Lyra2REv3, new in 0.14.0 
    [PSCustomObject]@{Algorithm = "lyra2vc0ban"; MinMemGB = 1; Fee = 1; Command = " --algo lyra2vc0ban"} #Lyra2vc0banHash, new in 0.13.0
    [PSCustomObject]@{Algorithm = "lyra2z";      MinMemGB = 1; Fee = 1; Command = " --algo lyra2z"} #Lyra2z
    [PSCustomObject]@{Algorithm = "lyra2zz";     MinMemGB = 1; Fee = 1; Command = " --algo lyra2zz"} #Lyra2zz, new in 0.16.0 
    [PSCustomObject]@{Algorithm = "mtp";         MinMemGB = 5; Fee = 2; Command = " --algo mtp"} #MTP, new with 0.15.0; CcminerTrex-v0.12.2b is 10% faster
    [PSCustomObject]@{Algorithm = "mtpnicehash"; MinMemGB = 5; Fee = 2; Command = " --algo mtp"} #MTP, new with 0.15.0; CcminerTrex-v0.12.2b is 10% faster
    [PSCustomObject]@{Algorithm = "neoscrypt";   MinMemGB = 1; Fee = 1; Command = " --algo neoscrypt --intensity 7"} #NeoScrypt
    [PSCustomObject]@{Algorithm = "phi2";        MinMemGB = 1; Fee = 1; Command = " --algo phi2"} #PHI2
    [PSCustomObject]@{Algorithm = "pipe" ;       MinMemGB = 1; Fee = 1; Command = " --algo pipe"} #Pipe, new in 12.0
    [PSCustomObject]@{Algorithm = "skunk";       MinMemGB = 1; Fee = 1; Command = " --algo skunk"} #Skunk
    [PSCustomObject]@{Algorithm = "tribus" ;     MinMemGB = 1; Fee = 1; Command = " --algo tribus"} #Tribus, new with 0.8
    [PSCustomObject]@{Algorithm = "x16r";        MinMemGB = 1; Fee = 1; Command = " --algo x16r"} #X16R, new in 0.11.0
    [PSCustomObject]@{Algorithm = "x16rt";       MinMemGB = 1; Fee = 1; Command = " --algo x16rt"} #X16rt, new in 0.16.0
    [PSCustomObject]@{Algorithm = "x16s";        MinMemGB = 1; Fee = 1; Command = " --algo x16s"} #X16S, new in 0.11.0
    [PSCustomObject]@{Algorithm = "x17";         MinMemGB = 1; Fee = 1; Command = " --algo x17"} #X17, new in 0.9.5
    [PSCustomObject]@{Algorithm = "x21s";        MinMemGB = 1; Fee = 1; Command = " --algo x21s"} #X21s, new in 0.13.0
    [PSCustomObject]@{Algorithm = "x22i";        MinMemGB = 1; Fee = 1; Command = " --algo x22i"} #X22i, new in 0.9.6
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --no-watchdog --no-crashreport $(if (-not $Config.ShowMinerWindow) {" --no-color"})"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $MinMemGB = $_.MinMemGB
        $Fee = $_.Fee

        if ($Algorithm -like "x*") {$WarmupTime = 30} else {$WarmupTime = 60} #seconds

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands --api-type ccminer-tcp --api-bind 127.0.0.1:$($Miner_Port) --url $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) --device $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Ccminer"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $Fee / 100}
                WarmupTime = $WarmupTime
            }
        }
    }
}
