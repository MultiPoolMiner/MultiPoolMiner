using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\TT-Miner.exe"
$HashSHA256 = "AE6B83839E9B6ACC78E30975597CB633BD029FAA51A31B88B23B6D53138851D5"
$Uri = "https://tradeproject.de/download/Miner/TT-Miner-2.2.5.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 9.2.148 or higher
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.148"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "ETHASH2gb";   MinMemGB = 2; Params = ""} #Ethash2GB
        [PSCustomObject]@{Algorithm = "ETHASH3gb";   MinMemGB = 3; Params = ""} #Ethash3GB
        [PSCustomObject]@{Algorithm = "ETHASH";      MinMemGB = 4; Params = ""} #Ethash
        [PSCustomObject]@{Algorithm = "LYRA2V3";     MinMemGB = 2; Params = ""} #LYRA2V3
        [PSCustomObject]@{Algorithm = "MTP";         MinMemGB = 6; Params = ""} #MTP
        [PSCustomObject]@{Algorithm = "MTPNICEHASH"; MinMemGB = 6; Params = ""} #MTP; TempFix: NiceHash only
        [PSCustomObject]@{Algorithm = "MYRGR";       MinMemGB = 2; Params = ""} #Myriad-Groestl
        [PSCustomObject]@{Algorithm = "UBQHASH";     MinMemGB = 2; Params = ""} #Ubqhash
        [PSCustomObject]@{Algorithm = "PROGPOW2gb";  MinMemGB = 2; Params = ""} #ProgPoW2gb
        [PSCustomObject]@{Algorithm = "PROGPOW3gb";  MinMemGB = 3; Params = ""} #ProgPoW3gb
        [PSCustomObject]@{Algorithm = "PROGPOW";     MinMemGB = 4; Params = ""} #ProgPoW
        [PSCustomObject]@{Algorithm = "PROGPOWH";    MinMemGB = 4; Params = ""} #ProgPoWh (Hora)
        [PSCustomObject]@{Algorithm = "PROGPOW092";  MinMemGB = 4; Params = ""} #ProgPoW092 (Hydnora)
        [PSCustomObject]@{Algorithm = "PROGPOWZ";    MinMemGB = 4; Params = ""} #ProgPoWZ
        [PSCustomObject]@{Algorithm = "TETHASHV1";   MinMemGB = 4; Params = ""} #TETHASHV1 (Teo)
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " -RH"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm ($_.Algorithm -split '-' | Select-Object -Index 0); $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = $_.Algorithm -replace 'NiceHash'<#TempFix#> -replace "ETHASH(\dgb)", "ETHASH" -replace "PROGPOW(\dgb)", "PROGPOW"
        $Parameters = $_.Parameters
        $MinMemGB = $_.MinMemGB

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
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("--api-bind 127.0.0.1:$($Miner_Port) -A $Algorithm -P $($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$($Commands.$_)$CommonParameters -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Claymore"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            }
        }
    }
}