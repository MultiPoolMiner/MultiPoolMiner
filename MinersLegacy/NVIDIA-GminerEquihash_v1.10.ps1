using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\miner.exe"
$HashSHA256 = "62C9AB99868016215DCDABFE0EBFBE5C904C347279D33B943C5DEC634DC677CA"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/Gminer/gminer_1_10_windows64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5034735.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "Equihash144_5"; MinMemGB = 1.7; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash192_7"; MinMemGB = 2.7; Params = ""}
    [PSCustomObject]@{Algorithm = "Equihash210_9"; MinMemGB = 1.3; Params = ""}
)
$CommonCommands = " --pec 0 --watchdog 0"

$Coins = [PSCustomObject]@{
    "ManagedByPool" = " --pers auto" #pers auto switching; https://bitcointalk.org/index.php?topic=2759935.msg43324268#msg43324268
    "Anon"          = " --pers AnonyPoW"
    "Bitcoingold"   = " --pers BgoldPoW"
    "Bitcoinz"      = " --pers BitcoinZ" #https://twitter.com/bitcoinzteam/status/1008283738999021568?lang=en
    "Safecoin"      = " --pers Safecoin"
    "Snowgem"       = " --pers sngemPoW"
    "Zelcash"       = " --pers ZelProof"
    "Zero"          = " --pers ZERO_PoW"
    "Zerocoin"      = " --pers ZERO_PoW"
    "LitecoinZ"     = " --pers ZcashPoW"
}

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation"

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Host} | ForEach-Object {
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
            $Params = Get-CommandPerDevice $_.Params $Miner_Device.Type_Vendor_Index

            if ($Algorithm_Norm -like "Equihash1445") {
                #define --pers for equihash1445
                if (($Coins | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) -contains $Pools.$Algorithm_Norm.CoinName) {
                    #Coin parameter, different per coin
                    $Pers = $Coins."$($Pools.$Algorithm_Norm.CoinName)"
                }
                else {
                    #Try auto if no coinname is available
                    $Pers = " --pers auto"
                }
            }
            else {$Pers = ""}

            if ($Algorithm_Norm -ne "Equihash1445" -or $Pers) {
                [PSCustomObject]@{
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = ("--algo $Algorithm$Pers --api $($Miner_Port)$(if ($Pools.$Algorithm_Norm.SSL) {" --ssl --ssl_verification 0"}) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$Params$CommonCommands --devices $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ',')" -replace "\s+", " ").trim()
                    HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API              = "Gminer"
                    Port             = $Miner_Port
                    URI              = $Uri
                    Fees             = [PSCustomObject]@{$Algorithm_Norm = 2 / 100}
                }
            }
        }
    }
}
