using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-EWBF2-Equihash\miner.exe"
$HashSHA256 = "9CB05EF5863CD3EB7D0C2E0E8B7D8EC527373F75DD2C3A6B4CC736B401EB6400"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/EWBF2/EWBF.Equihash.miner.v0.4.zip"
$ManualUri = "https://mega.nz/#F!fsAlmZQS!CwVgFfBDduQI-CbwVkUEpQ"
$Port = "421{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash-96_5"; Pers = ""; MinMemGB = 2; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-144_5"; Pers = ""; MinMemGB = 2; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-192_7"; Pers = ""; MinMemGB = 3; Params = ""}
    [PSCustomObject]@{Algorithm = "aion"; Pers = " --pers AION0PoW"; MinMemGB = 2; Params = ""} #https://bitcointalk.org/index.php?topic=4466962.msg42333802#msg42333802
    #Removed, conflicts with Equihash-144_5[PSCustomObject]@{Algorithm = "zhash"; Pers = " --pers BitcoinZ"; MinMemGB = 2; Params = ""} # https://twitter.com/bitcoinzteam/status/1008283738999021568?lang=en
)

$CommonCommands = " --fee 0 --intensity 64"

$Coins = [PSCustomObject]@{
    "BitcoinGold" = " --pers BgoldPoW"
    "BitcoinZ"    = " --pers BitcoinZ"
    "Minexcoin"   = ""
    "SnowGem"     = " --pers sngemPoW"
    "Zero"        = " --pers ZERO_PoW"
    "ZeroCoin"    = " --pers ZERO_PoW"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm = ($_.Algorithm) -replace "Equihash-"
        $Algorithm_Norm = Get-Algorithm $_.Algorithm
        $MinMemGB = $_.MinMemGB

        #Pers parameter, can be different per coin
        if ($_.Pers) {$Pers = $_.Pers}
        else {$Pers = $($Coins."$($Pools.$Algorithm_Norm.CoinName)")}
        
        if ($Miner_Device = @($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1000000000)})) {
            [PSCustomObject]@{
                Name             = $Miner_Name
                DeviceName       = $Miner_Device.Name
                Path             = $Path
                HashSHA256       = $HashSHA256
                Arguments        = ("--algo $Algorithm$Pers --eexit 1 --api 127.0.0.1:$Miner_Port --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($_.Params)$CommonCommands --cuda_devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join '')" -replace "\s+", " ").trim()
                HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API              = "DSTM"
                Port             = $Miner_Port
                URI              = $Uri
                Fees             = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
                ExtendInterval   = 2
                PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
            }
        }
    }
}
