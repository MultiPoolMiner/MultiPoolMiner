using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-EWBF-Equihash\miner.exe"
$HashSHA256 = "84DD02DEBBF2B0C5ED7EEBF813305543265E34EC98635139787BF8B882E7C7B4"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ewbf/Zec.Miner.0.3.4b.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=1707546.0"
$Port = "40{0:d2}"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

if (-not $Pools.Equihash.SSL) {
    $Devices | Select-Object Model -Unique | ForEach-Object {
        $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

        $Miner_Name = ((@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"

        [PSCustomObject]@{
            Name             = $Miner_Name
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = "--eexit 1 --api 127.0.0.1:$Miner_Port --server $($Pools.Equihash.Host) --port $($Pools.Equihash.Port) --user $($Pools.Equihash.User) --pass $($Pools.Equihash.Pass) --fee 0 --intensity 64 --cuda_devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')"
            HashRates        = [PSCustomObject]@{"Equihash" = $Stats."$($Miner_Name)_Equihash_HashRate".Week}
            API              = "DSTM"
            Port             = $Miner_Port
            URI              = $Uri
            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
            PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
        }
    }
}
