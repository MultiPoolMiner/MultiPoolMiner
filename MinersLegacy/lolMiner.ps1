using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\AMD_NVIDIA-lolMiner\lolminer.exe"
$HashSHA256 = "1325784F9A9FF11BB077CC66937B66C28422D4E71DD46AE959CCAD87D7799065"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/lolMiner/lolMiner_v043_Win64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"
$Port = "40{0:d2}"


$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash965";  MinMemGB = 1.8; Fee = 1; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash1445"; MinMemGB = 2.1; Fee = 2; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash1927"; MinMemGB = 2.7; Fee = 2; Params = ""}
)

$CommonCommands = ""

$Coins = [PSCustomObject]@{
    "Asofe"       = "ASF"
    "BitcoinZ"    = "BTCZ"
    "BitcoinGold" = "BTG"
    "LitecoinZ"   = "LTZ"
    "Heptacoin"   = "HEPTA"
    "MinexCoin"   = "MNX"
    "SafeCoin"    = "SAFE"
    "SafeCash"    = "SCASH"
    "Zelcash"     = "ZEL"
    "Zero"        = "ZER"
    "Zerocoin"    = "ZER"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = $Devices | Where-Object Type -EQ "GPU"

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.Algorithm
        $MinMemGB = $_.MinMemGB
        $Params = $_.Params

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1GB)})) {

            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

            switch ($Algorithm_Norm) {
                "Equihash965" {
                    $Coin = "MNX"
                }
                "Equihash1445" {
                    #ZergPool allows pers auto switching; https://bitcointalk.org/index.php?topic=2759935.msg43324268#msg43324268
                    if ($Pools.$Algorithm_Norm.Name -like "ZergPool*") {
                        $Coin = "AUTO144"
                    }
                    else {
                        #Coin parameter, different per coin
                        $Coin = $Coins."$($Pools.$Algorithm_Norm.CoinName)"
                    }
                }
                "Equihash1927" {
                    $Coin = "ZER"
                }
            }

            if ($Coin) {
            
                #Disable_memcheck
                if ($Miner_Device.Vendor -eq "NVIDIA Corporation" -and $Algorithm_Norm -ne "Equihash965") {$Params += " -disable_memcheck=1"}

                $ConfigFileName = "$Miner_Name-$($Pools.$Algorithm_Norm.Name)-$($Pools.$Algorithm_Norm.Algorithm).txt"
                $Arguments = [PSCustomObject]@{
                    ConfigFile = [PSCustomObject]@{
                        FileName = $ConfigFilename
                        Content  = [PSCustomObject]@{
                            DEFAULT = [PSCustomObject]@{
                                APIPORT    = $Miner_Port
                                COIN       = $Coin
                                DEVICES    = @($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Index})
                                POOLS      = @([PSCustomObject]@{
                                    POOL = $Pools.$Algorithm_Norm.Host
                                    PORT = $Pools.$Algorithm_Norm.Port
                                    USER = $Pools.$Algorithm_Norm.User
                                    PASS = $Pools.$Algorithm_Norm.Pass
                                })
                                SHORTSTATS = 10 #for more stable hash rate stats
                            }
                        }
                    }
                    Commands = "-usercfg=$ConfigFileName -profile=DEFAULT$Params$CommonCommands"
                }

                [PSCustomObject]@{
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = $Arguments
                    HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API              = "lolMiner"
                    Port             = $Miner_Port
                    URI              = $Uri
                    Fees             = [PSCustomObject]@{$Algorithm_Norm = $_.Fee / 100}
                    BenchmarkSamples = 10
                }
            }
        }
    }
}
