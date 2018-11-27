using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\miner.exe"
$HashSHA256 = "84DD02DEBBF2B0C5ED7EEBF813305543265E34EC98635139787BF8B882E7C7B4"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ewbf/Zec.Miner.0.3.4b.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=1707546.0"
$Port = "40{0:d2}"


$Commands = [PSCustomObject]@{
    "equihash" = "" #Equihash
}

$CommonCommands = " --intensity 64"

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_

        if ($Config.UseDeviceNameForStatsFileNaming) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
        }
        else {
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        }

        [PSCustomObject]@{
            Name             = $Miner_Name
            DeviceName       = $Miner_Device.Name
            Path             = $Path
            HashSHA256       = $HashSHA256
            Arguments        = ("--eexit 1 --api 127.0.0.1:$($Miner_Port) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($_.Commands)$CommonCommands --cuda_devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_PlatformId_Index)}) -join ' ')" -replace "\s+", " ").trim()
            HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API              = "DSTM"
            Port             = $Miner_Port
            URI              = $Uri
            Fees             = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
            PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
        }
    }
}
