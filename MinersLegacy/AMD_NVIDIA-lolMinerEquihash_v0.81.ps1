using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\lolminer.exe"
$HashSHA256 = "CB4EAB2F1E1253636A1D2714F9748FD303266643E54914B9AC2FFE77E36FF919"
$Uri = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/0.8.1/lolMiner_v081_Win64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{Algorithm = "Equihash965";  MinMemGB = 1.35; Params = ""}
        [PSCustomObject]@{Algorithm = "Equihash1445"; MinMemGB = 1.85; Params = ""}
        [PSCustomObject]@{Algorithm = "Equihash1505"; MinMemGB = 2.75; Params = ""}
        [PSCustomObject]@{Algorithm = "Equihash1927"; MinMemGB = 3.0;  Params = ""}
        [PSCustomObject]@{Algorithm = "Equihash2109"; MinMemGB = 1.0;  Params = ""} # new with 0.6 alpha 3
        [PSCustomObject]@{Algorithm = "Cuckatoo31";   MinMemGB = 4.0;  Params = ""} # new with 0.8
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " --workbatch HIGH --shortstats 5 --digits 3"}

$Coins = [PSCustomObject]@{
    "ManagedByPool" = "AUTO" #pers auto switching; https://bitcointalk.org/index.php?topic=2759935.msg43324268#msg43324268
    "Aion"          = "AION"
    "Anon"          = "ANON"
    "Asofe"         = "ASF"
    "Beam"          = "BEAM"
    "BitcoinZ"      = "BTCZ"
    "BitcoinGold"   = "BTG"
    "Bithereum"     = "BTH"
    "Genesis"       = "GENX"
    "HeptaCoin"     = "HEPTA"
    "LiteCoinZ"     = "LTZ"
    "MinexCoin"     = "MNX"
    "SafeCoin"      = "SAFE"
    "SnowGem"       = "XSG"
    "Vidulum"       = "VDL"
    "ZelCash"       = "ZEL"
    "ZeroCoin"      = "ZER"
}

$Devices = $Devices | Where-Object Type -EQ "GPU"
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | ForEach-Object {
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $_.Parameters $Miner_Device.Type_Vendor_Index
            }

            #Miner uses --coin parameter (as opposed to algo name like other miners)
            $Coin = $Coins.$($Pools.$Algorithm_Norm.CoinName)
            if (-not $Coin -or $Coin -eq "AUTO") {
                switch ($Algorithm_Norm) {
                    "Equihash965" {
                        #Try auto if no coinname is available
                        $Coin = "MNX"
                    }
                    "Equihash1445" {
                        #Try auto if no coinname is available
                        $Coin = "AUTO144_5"
                    }
                    "Equihash1505" {
                        $Coin = "BEAM"
                    }
                    "Equihash1927" {
                        #Try auto if no coinname is available
                        $Coin = "AUTO192_7"
                    }
                    "Cuckatoo31" {
                        $Coin = "GRIN-AT31"
                    }
                    default {$Coin = ""}
                }
            }

            if ($Coin) {
                #Disable_memcheck
                if ($Miner_Device.Vendor -eq "NVIDIA Corporation" -and $Algorithm_Norm -ne "Equihash965") {$Parameters += " --disable_memcheck 1"}

                [PSCustomObject]@{
                    Name             = $Miner_Name
                    BaseName         = $Miner_BaseName
                    Version          = $Miner_Version
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = ("--coin $coin --pool $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.pass) --apiport $Miner_Port$Parameters$CommonParameters $(if ($Pools.$Algorithm_Norm.SSL) {"--tls 1 "} else {"--tls 0 "})--devices $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.PCIBus_Type_Index}) -join ',')").trim()
                    HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API              = "lolMinerApi"
                    Port             = $Miner_Port
                    URI              = $Uri
                    Fees             = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
                    WarmupTime       = 0
                }
            }
        }
    }
}
