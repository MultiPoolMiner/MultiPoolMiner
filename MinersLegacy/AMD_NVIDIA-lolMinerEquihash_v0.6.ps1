using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\lolminer.exe"
$HashSHA256 = "A6374413D2B47889EA2C6F6E37D6ACF00343563441C6FF533087285C59D53B9E"
$Uri = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/0.6/lolMiner_v06_Win64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash965";  MinMemGB = 0.5;  Fee = 1; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash1445"; MinMemGB = 1.85; Fee = 1.5; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash1927"; MinMemGB = 3.0;  Fee = 2; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash2109"; MinMemGB = 1.0;  Fee = 2; Params = ""} # new with 0.6 alpha 3
)
$CommonCommands = " --workbatch HIGH --shortstats 10"

$Coins = [PSCustomObject]@{
    "ManagedByPool" = "AUTO" #pers auto switching; https://bitcointalk.org/index.php?topic=2759935.msg43324268#msg43324268
    "Asofe"         = "ASF"
    "BitcoinZ"      = "BTCZ"
    "BitcoinCandy"  = "CDY" #new in 0.43b
    "BitcoinGold"   = "BTG"
    "BitcoinRM"     = "BCRM" #new in 0.43b
    "ExchangeCoin"  = "EXCC" #new in 0.6
    "Genesis"       = "GENX"
    "LitecoinZ"     = "LTZ"
    "Heptacoin"     = "HEPTA"
    "MinexCoin"     = "MNX"
    "SafeCoin"      = "SAFE"
    "Zelcash"       = "ZEL"
    "Zero"          = "ZER"
    "Zerocoin"      = "ZER"
}

$Devices = $Devices | Where-Object Type -EQ "GPU"

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.Algorithm
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {

            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            }

            #Get commands for active miner devices
            $Params = <#temp fix#> Get-CommandPerDevice $_.Params $Miner_Device.Type_Index

            switch ($Algorithm_Norm) {
                "Equihash965" {
                    $Coin = "MNX"
                }
                "Equihash1445" {
                    if (($Coins | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) -contains $Pools.$Algorithm_Norm.CoinName) {
                        #Coin parameter, different per coin
                        $Coin = $Coins."$($Pools.$Algorithm_Norm.CoinName)"
                    }
                    else {
                        #Try auto if no coinname is available
                        $Coin = "AUTO144_5"
                    }
                }
                "Equihash1927" {
                    $Coin = "ZER"
                }
                "Equihash2109" {
                    if (($Coins | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) -contains $Pools.$Algorithm_Norm.CoinName) {
                        #Coin parameter, different per coin
                        $Coin = $Coins."$($Pools.$Algorithm_Norm.CoinName)"
                    }
                    else {
                        $Coin = "AUT210_9"
                    }
                }
            }

            if ($Coin) {
                #Disable_memcheck
                if ($Miner_Device.Vendor -eq "NVIDIA Corporation" -and $Algorithm_Norm -ne "Equihash965") {$Params += " --disable_memcheck 1"}

                [PSCustomObject]@{
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = ("--pool $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.pass) --apiport $Miner_Port --coin $coin$Params$CommonCommands --devices $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Index}) -join ',')").trim()
                    HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API              = "lolMinerApi"
                    Port             = $Miner_Port
                    URI              = $Uri
                    Fees             = [PSCustomObject]@{$Algorithm_Norm = $_.Fee / 100}
                }
            }
        }
    }
}
