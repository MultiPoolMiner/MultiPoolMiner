using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\miner.exe"
$HashSHA256 = "C3CB1770B93611F45CC194DF11188E56ACE58DD718F5E4260C3ED65EABB1F6B7"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/EWBF2/EWBF.Equihash.miner.v0.6.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash-96_5";  MinMemGB = 1.8; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-144_5"; MinMemGB = 1.7; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-192_7"; MinMemGB = 2.7; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-210_9"; MinMemGB = 1.3; Params = ""}
)
$CommonCommands = " --pec --intensity 64"

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.Algorithm
        $Algorithm = ($_.Algorithm) -replace "Equihash-"
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

            if ($Algorithm_Norm -ne "Equihash1445" -or $Pers) {
                [PSCustomObject]@{
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = ("--algo $Algorithm$Pers --eexit 1 --api 127.0.0.1:$($Miner_Port) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$Params$CommonCommands --cuda_devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
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
    }
}
