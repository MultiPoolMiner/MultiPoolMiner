using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\NVIDIA-EWBF2Equihash\miner.exe"
$HashSHA256 = "BB17BA6C699F6BC7A4465E641E15E1A7AABF1D884BF908A603DBAA1A705EDCD9"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/EWBF2/EWBF.Equihash.miner.v0.5.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash-96_5";  MinMemGB = 1.8; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-144_5"; MinMemGB = 2;   Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-192_7"; MinMemGB = 2.7; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash-210_9"; MinMemGB = 1.3; Params = ""}
)

$CommonCommands = " --pec --intensity 64"

$Coins = [PSCustomObject]@{
    "Aion"        = " --pers AION0PoW"
    "Bitcoingold" = " --pers BgoldPoW"
    "Bitcoinz"    = " --pers BitcoinZ" #https://twitter.com/bitcoinzteam/status/1008283738999021568?lang=en
    "Minexcoin"   = ""
    "Safecoin"    = " --pers Safecoin"
    "Snowgem"     = " --pers sngemPoW"
    "Zelcash"     = " --pers ZelProof"
    "Zero"        = " --pers ZERO_PoW"
    "Zerocoin"    = " --pers ZERO_PoW"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.Algorithm
        $Algorithm = ($_.Algorithm) -replace "Equihash-"
        $MinMem = $_.MinMemGB * 1GB

        if ($Miner_Device = @($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMem)})) {

            #Get commands for active miner devices
            $Commands.$_ = Get-CommandPerDevice $Commands.$_ $Miner_Device.Type_Vendor_Index

            $Pers = ""
            #define --pers for equihash1445
            if ($Algorithm_Norm -eq "Equihash1445") {
                #ZergPool allows pers auto switching; https://bitcointalk.org/index.php?topic=2759935.msg43324268#msg43324268
                if ($Pools.$Algorithm_Norm.Name -like "ZergPool*") {
                    $Pers = " --pers auto"
                }
                #Pers parameter, different per coin
                elseif ($Coins.$($Pools.$Algorithm_Norm.CoinName) {
                    $Pers = " --pers $Coins.$($Pools.$Algorithm_Norm.CoinName)"
                }
            }

            if ($Algorithm_Norm -ne "Equihash1445" -or $Pers) {
                [PSCustomObject]@{
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = ("--algo $Algorithm$Pers --eexit 1 --api 127.0.0.1:$Miner_Port --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$($_.Params)$CommonCommands --cuda_devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                    HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API              = "DSTM"
                    Port             = $Miner_Port
                    URI              = $Uri
                    Fees             = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
                    BenchmarkSamples = 10
                    PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                }
            }
        }
    }
}
