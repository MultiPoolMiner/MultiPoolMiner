using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\AMD_NVIDIA-PhoenixminerEthash\PhoenixMiner.exe"
$HashSHA256 = "79D46481B679F96FCA9C8790ED94EBFC6453ED4AE45336AEB720A51CEA7341FB"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/phoenixminer/PhoenixMiner_3.5d_Windows.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "ethash2gb"; MinMemGB = 2; Params = @()} #Ethash2GB
    [PSCustomObject]@{Algorithm = "ethash3gb"; MinMemGB = 3; Params = @()} #Ethash3GB
    [PSCustomObject]@{Algorithm = "ethash"   ; MinMemGB = 4; Params = @()} #Ethash
)
$CommonCommandsAll    = " -log 0"
$CommonCommandsNvidia = " -mi 14"
$CommonCommandsAmd    = " -clgreen 1 -gt 15 -mi 14"

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Devices = @($Devices | Where-Object Type -EQ "GPU")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Name = (@($Name) + @($Device.Name | Sort-Object) | Select-Object) -join '-'

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {
            $Vendor = " -amd"
            $CommonCommands = $CommonCommandsAmd + $CommonCommandsAll
        }
        "NVIDIA Corporation" {
            $Vendor = " -nvidia"
            $CommonCommands = $CommonCommandsNvidia + $CommonCommandsAll
        }
        Default {
            $Vendor = ""
            $CommonCommands = $CommonCommandsAll
        }
    }

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $MinMem = $_.MinMemGB * 1GB

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMem})) {

            [PSCustomObject]@{
                Name           = $Miner_Name
                DeviceName     = $Miner_Device.Name
                Path           = $Path
                HashSHA256     = $HashSHA256
                Arguments      = ("-rmode 0 -cdmport $Miner_Port -cdm 1 -pool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass)$($_.Params)$CommonCommands -proto 4 -coin auto$Vendor -gpus $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index + 1)}) -join ',')" -replace "\s+", " ").trim()
                HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API            = "Claymore"
                Port           = $Miner_Port
                URI            = $Uri
                Fees           = [PSCustomObject]@{"$Algorithm_Norm" = 0.65 / 100}

            }
        }
    }
}
