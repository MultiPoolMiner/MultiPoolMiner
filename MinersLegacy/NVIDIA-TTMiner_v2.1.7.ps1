using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\TT-Miner.exe"
$HashSHA256 = "5BE8696FDE19FAC090E6B1AD74422885D3DBDA08BD00F9B2C786C61C7F459266"
$Uri = "https://TradeProject.de/download/Miner/TT-Miner-2.1.7.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"
$Port = "40{0:d2}"

# Miner requires CUDA 9.2.00 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

if ($DriverVersion -and [System.Version]$DriverVersion -ge "10.0") {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "ETHASH2gb-100"  ; MinMemGB = 2; Params = ""} #Ethash2GB algo for CUDA 10.0
        [PSCustomObject]@{Algorithm = "ETHASH3gb-100"  ; MinMemGB = 3; Params = ""} #Ethash3GB algo for CUDA 10.0
        [PSCustomObject]@{Algorithm = "ETHASH-100"     ; MinMemGB = 4; Params = ""} #Ethash algo for CUDA 10.0
        [PSCustomObject]@{Algorithm = "UBQHASH-100"    ; MinMemGB = 2; Params = ""} #Ubqhash algo for CUDA 10.0
        [PSCustomObject]@{Algorithm = "PROGPOW2gb-100" ; MinMemGB = 2; Params = ""} #ProgPoW2gb algo for CUDA 10.0
        [PSCustomObject]@{Algorithm = "PROGPOW3gb-100" ; MinMemGB = 3; Params = ""} #ProgPoW3gb algo for CUDA 10.0
        [PSCustomObject]@{Algorithm = "PROGPOW-100"    ; MinMemGB = 4; Params = ""} #ProgPoW algo for CUDA 10.0
        [PSCustomObject]@{Algorithm = "MTP-100"        ; MinMemGB = 6; Params = ""} #MTP algo for CUDA 10.0
    )
}
elseif ($DriverVersion -and [System.Version]$DriverVersion -ge "9.2") {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "ETHASH2gb-92"  ; MinMemGB = 2; Params = ""} #Ethash2GB algo for CUDA 9.2
        [PSCustomObject]@{Algorithm = "ETHASH3gb-92"  ; MinMemGB = 3; Params = ""} #Ethash3GB algo for CUDA 9.2
        [PSCustomObject]@{Algorithm = "ETHASH-92"     ; MinMemGB = 4; Params = ""} #Ethash algo for CUDA 9.2
        [PSCustomObject]@{Algorithm = "UBQHASH-92"    ; MinMemGB = 2; Params = ""} #Ubqhash algo for CUDA 9.2
        [PSCustomObject]@{Algorithm = "PROGPOW2gb-92" ; MinMemGB = 2; Params = ""} #ProgPoW2gb algo for CUDA 9.2
        [PSCustomObject]@{Algorithm = "PROGPOW3gb-92" ; MinMemGB = 3; Params = ""} #ProgPoW3gb algo for CUDA 9.2
        [PSCustomObject]@{Algorithm = "PROGPOW-92"    ; MinMemGB = 4; Params = ""} #ProgPoW algo for CUDA 9.2
        [PSCustomObject]@{Algorithm = "MTP-92"        ; MinMemGB = 6; Params = ""} #MTP algo for CUDA 9.2
    )
}
$CommonCommands = " -RH"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Where-Object {$Pools.(Get-Algorithm ($_.Algorithm -split '-' | Select-Object -Index 0)).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm = $_.Algorithm -replace "ETHASH(\dgb)-", "ETHASH-" -replace "PROGPOW(\dgb)-", "PROGPOW-"
        $Algorithm_Norm = Get-Algorithm ($_.Algorithm -split '-' | Select-Object -Index 0)
        $Params = $_.Params
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = "$Name-$($Miner_Device.count)x$($Miner_Device.Model_Norm | Sort-Object -unique)"		
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            }

            #Get commands for active miner devices
            $Params = Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name               = $Miner_Name
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("--api-bind 127.0.0.1:$($Miner_Port) -A $Algorithm -P $($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API                = "Claymore"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            }
        }
    }
}
