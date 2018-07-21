using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\AMD_NVIDIA-PhoenixMiner\PhoenixMiner.exe"
$HashSHA256 = "4E8540AA48C9D2245F22F68440494C6A39B16B107B600AFED69C5B7297DC7992"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/phoenixminer/PhoenixMiner_3.0c.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"
$Port = "133{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "ethash2gb"; MinMemGB = 2; Params = @()} #Ethash2GB
    [PSCustomObject]@{Algorithm = "ethash3gb"; MinMemGB = 3; Params = @()} #Ethash3GB
    [PSCustomObject]@{Algorithm = "ethash"   ; MinMemGB = 4; Params = @()} #Ethash
)
$CommonCommands = " -log 0"

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMemGB * 1000000000})) {

            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

            [PSCustomObject]@{
                Name           = $Miner_Name
                DeviceName     = $Miner_Device.Name
                Path           = $Path
                HashSHA256     = $HashSHA256
                Arguments      = ("-rmode 0 -cdmport $Miner_Port -cdm 1 -pool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass)$CommonCommands -proto 4 -coin auto -amd -gpus $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index + 1)}) -join '')" -replace "\s+", " ").trim()
                HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API            = "Claymore"
                Port           = $Miner_Port
                URI            = $Uri
                Fees           = [PSCustomObject]@{"$Algorithm_Norm" = 0.65 / 100}
            }
        }
    }
}
