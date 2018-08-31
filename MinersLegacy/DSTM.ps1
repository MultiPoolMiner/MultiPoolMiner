using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-DSTM-Equihash\zm.exe"
$HashSHA256 = "3666C1870D83F9A0E813671ADFD920EA87E64A6174ECE357E5B4D1B65191B5D0"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/dstm/zm_0.6.1_win.zip"
$Port = "40{0:d2}"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Miner_Name = ((@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace "[-]{2,}", "-"

    [PSCustomObject]@{
        Name       = $Miner_Name
        DeviceName = $Miner_Device.Name
        Path       = $Path
        HashSHA256 = $HashSHA256
        Arguments  = "--telemetry=127.0.0.1:$($Miner_Port) --server $(if ($Pools.Equihash.SSL) {'ssl://'})$($Pools.Equihash.Host) --port $($Pools.Equihash.Port) --user $($Pools.Equihash.User) --pass $($Pools.Equihash.Pass) --color --dev $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')"
        HashRates  = [PSCustomObject]@{"Equihash" = $Stats."$($Miner_Name)_Equihash_HashRate".Week}
        API        = "DSTM"
        Port       = $Miner_Port
        URI        = $Uri
        Fees       = [PSCustomObject]@{"Equihash" = 2 / 100}
    } 
}
