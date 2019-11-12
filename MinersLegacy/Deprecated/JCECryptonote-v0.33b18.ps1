using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\jce_cn_gpu_miner64.exe"
$HashSHA256 = "2D359EC26DE8C150341DC8665FB0F7C94909D1DE061A12ABE5C2EE391B5ADBF8"
$Uri = "https://github.com/jceminer/cn_gpu_miner/raw/master/jce_cn_gpu_miner.033b18.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3281187.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject[]]@(
    #Unprofitable [PSCustomObject]@{Algorithm = "Cryptonight";           MinMemGB = 2; Fee = 0.9; Command = " --variation 1"} #Original Cryptonight
    #Unprofitable [PSCustomObject]@{Algorithm = "Cryptolight";           MinMemGB = 1; Fee = 0.9; Command = " --variation 2"} #Original Cryptolight
    #Unprofitable [PSCustomObject]@{Algorithm = "CryptonightV7";         MinMemGB = 2; Fee = 0.9; Command = " --variation 3"} #Cryptonight V7 fork of April-2018
    #Unprofitable [PSCustomObject]@{Algorithm = "CryptolightV7";         MinMemGB = 1; Fee = 0.9; Command = " --variation 4"} #Cryptolight V7 fork of April-2018
    [PSCustomObject]@{Algorithm = "CryptonightHeavy";      MinMemGB = 4; Fee = 2.1; Command = " --variation 5"} #Cryptonight-Heavy
    [PSCustomObject]@{Algorithm = "CryptonightLiteIpbc";   MinMemGB = 1; Fee = 0.9; Command = " --variation 6"} #Cryptolight-IPBC
    [PSCustomObject]@{Algorithm = "CryptonightXtl";        MinMemGB = 2; Fee = 0.9; Command = " --variation 7"} #Cryptonight-XTL fork of May-2018
    [PSCustomObject]@{Algorithm = "CryptonightXao";        MinMemGB = 2; Fee = 0.9; Command = " --variation 8"} #Cryptonight-Alloy
    [PSCustomObject]@{Algorithm = "CryptonightMarketCash"; MinMemGB = 2; Fee = 0.9; Command = " --variation 9"} #Cryptonight-MKT
    [PSCustomObject]@{Algorithm = "CryptonightRto";        MinMemGB = 2; Fee = 0.9; Command = " --variation 10"} #Cryptonight-Arto
    [PSCustomObject]@{Algorithm = "CryptonightFast";       MinMemGB = 2; Fee = 0.9; Command = " --variation 11"} #Cryptonight-Fast MSR fork of June-2018
    [PSCustomObject]@{Algorithm = "CryptonightHeavyHaven"; MinMemGB = 4; Fee = 2.1; Command = " --variation 12"} #Cryptonight-Haven fork of June-2018
    [PSCustomObject]@{Algorithm = "CryptonightHeavyTube";  MinMemGB = 4; Fee = 2.1; Command = " --variation 13"} #Cryptonight-BitTube v2 of July-2018
    [PSCustomObject]@{Algorithm = "CryptonightRed";        MinMemGB = 1; Fee = 0.9; Command = " --variation 14"} #Cryptonight-Red
    [PSCustomObject]@{Algorithm = "CryptonightV8";         MinMemGB = 2; Fee = 0.9; Command = " --variation 15"} #Cryptonight V8 fork of October-2018
    #[PSCustomObject]@{Algorithm = "_AUTO_";                MinMemGB = 2; Fee = 0;   Command = " --variation 16"} #Pool-selected autoswitch, not supported by MPM
    [PSCustomObject]@{Algorithm = "CryptonightDark";       MinMemGB = 1; Fee = 0.9; Command = " --variation 17"} #Cryptonight-Dark
    [PSCustomObject]@{Algorithm = "CryptonightSwap";       MinMemGB = 2; Fee = 0.9; Command = " --variation 18"} #Cryptonight-Swap
    [PSCustomObject]@{Algorithm = "CryptonightuPlexa";     MinMemGB = 2; Fee = 0.9; Command = " --variation 19"} #Cryptonight-uPlexa
    [PSCustomObject]@{Algorithm = "CryptonightTurtle";     MinMemGB = 2; Fee = 0.9; Command = " --variation 20"} #Cryptonight-Turtle
    [PSCustomObject]@{Algorithm = "CryptonightStellite";   MinMemGB = 2; Fee = 0.9; Command = " --variation 21"} #Cryptonight-Stellite
    [PSCustomObject]@{Algorithm = "CryptonightWaltzGraft"; MinMemGB = 2; Fee = 0.9; Command = " --variation 22"} #Cryptonight-WaltzGraft
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " --stakjson --no-cpu --auto --no-warmup --low"} #Miner with low priority not to freeze your computer. Has a very small impact on performances. Recommended.

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "AMD")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1
                
    $Commands | ForEach-Object {$Algorithm_Norm = $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Fee = $_.Fee
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object {$Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$(if ($Pools.$Algorithm_Norm.SSL) {" -ssl"})$(if ($Pools.$Algorithm_Norm.Name -like "NiceHash*") {" --nicehash"}) --mport $Miner_Port -g $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_PlatformId_Index)}) -join ',')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "XmRig"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $Fee / 100}
            }
        } 
    }
}
