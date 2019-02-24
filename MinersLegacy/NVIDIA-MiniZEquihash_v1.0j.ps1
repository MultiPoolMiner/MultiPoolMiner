using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\MiniZ.exe"
$HashSHA256 = "75557F22E072263038EF08FEEF38B5D9C53234FFDC7A9C06EFFF2018A2A1F880"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/MiniZ/miniZ_v1.0j_cuda10_win-x64.zip"
$ManualUri = "https://miniz.ch/download"

# Miner requires CUDA 10.0.00 or higher
$DriverVersion = ((Get-Device | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredVersion = "10.0.00"
if ($DriverVersion -and [System.Version]$DriverVersion -lt [System.Version]$RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash144,5"; MinMemGB = 2.0; Params = ""}
)
$CommonCommands = " --intensity 100 --latency --extra"

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Miner_Device | Select-Object -First 1 -ExpandProperty Index) + 3

    $Commands | Where-Object {$Pools.(Get-Algorithm ($_.Algorithm -replace ",")).Host} | ForEach-Object {
        $Algorithm = $_.Algorithm -replace "Equihash"
        $Algorithm_Norm = Get-Algorithm ($_.Algorithm -replace ",")
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Miner_Device | Where-Object {$([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            }

            #Get commands for active miner devices
            $Params = <#temp fix#> Get-CommandPerDevice $_.Params $Miner_Device.Type_Vendor_Index

            if ($Algorithm_Norm -like "Equihash1445") {
                #define --pers for equihash1445
                $Pers = " --pers $(Get-EquihashPers -CoinName $Pools.$Algorithm_Norm.CoinName -Default 'auto')"
            }
            else {$Pers = ""}

            [PSCustomObject]@{
                Name               = $Miner_Name
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("--par=$Algorithm $Pers --telemetry 0.0.0.0:$($Miner_Port) --server $(if ($Pools.$Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$Params$CommonCommands --cuda-devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                HashRates          = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API                = "MiniZ"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
            }
        }
    }
}
