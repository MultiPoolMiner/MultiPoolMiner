using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\jce_cn_cpu_miner64.exe"
$HashSHA256 = "15E5B1BFCD972F1D2E6C4298ED955603890D6C77F83C19591EF558A3E9606F35"
$Uri = "https://github.com/jceminer/cn_cpu_miner/raw/master/jce_cn_cpu_miner.windows.033q.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3281187.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Commands = [PSCustomObject[]]@(
    #Unprofitable [PSCustomObject]@{Algorithm = "Cryptonight";           MinMemGB = 2; Command = " --variation 1"} #Original Cryptonight
    #Unprofitable [PSCustomObject]@{Algorithm = "Cryptolight";           MinMemGB = 1; Command = " --variation 2"} #Original Cryptolight
    #Unprofitable [PSCustomObject]@{Algorithm = "CryptonightV7";         MinMemGB = 2; Command = " --variation 3"} #Cryptonight V7 fork of April-2018
    #Unprofitable [PSCustomObject]@{Algorithm = "CryptolightV7";         MinMemGB = 15; Command = " --variation 4"} #Cryptolight V7 fork of April-2018
    [PSCustomObject]@{Algorithm = "CryptonightHeavy";      MinMemGB = 4; Command = " --variation 5"} #Cryptonight-Heavy
    [PSCustomObject]@{Algorithm = "CryptonightLiteIpbc";   MinMemGB = 1; Command = " --variation 6"} #Cryptolight-IPBC
    [PSCustomObject]@{Algorithm = "CryptonightXtl";        MinMemGB = 2; Command = " --variation 7"} #Cryptonight-XTL fork of May-2018
    [PSCustomObject]@{Algorithm = "CryptonightXao";        MinMemGB = 2; Command = " --variation 8"} #Cryptonight-Alloy
    [PSCustomObject]@{Algorithm = "CryptonightMarketCash"; MinMemGB = 2; Command = " --variation 9"} #Cryptonight-MKT
    [PSCustomObject]@{Algorithm = "CryptonightRto";        MinMemGB = 2; Command = " --variation 10"} #Cryptonight-Arto
    [PSCustomObject]@{Algorithm = "CryptonightFast";       MinMemGB = 2; Command = " --variation 11"} #Cryptonight-Fast MSR fork of June-2018
    [PSCustomObject]@{Algorithm = "CryptonightHeavyHaven"; MinMemGB = 4; Command = " --variation 12"} #Cryptonight-Haven fork of June-2018
    [PSCustomObject]@{Algorithm = "CryptonightHeavyTube";  MinMemGB = 4; Command = " --variation 13"} #Cryptonight-BitTube v2 of July-2018
    [PSCustomObject]@{Algorithm = "CryptonightRed";        MinMemGB = 1; Command = " --variation 14"} #Cryptonight-Red
    [PSCustomObject]@{Algorithm = "CryptonightV8";         MinMemGB = 2; Command = " --variation 15"} #Cryptonight V8 fork of October-2018
    #[PSCustomObject]@{Algorithm = "_AUTO_";                MinMemGB = 2;   Command = " --variation 16"} #Pool-selected autoswitch, not supported by MPM
    [PSCustomObject]@{Algorithm = "CryptonightDark";       MinMemGB = 1; Command = " --variation 17"} #Cryptonight-Dark
    [PSCustomObject]@{Algorithm = "CryptonightSwap";       MinMemGB = 2; Command = " --variation 18"} #Cryptonight-Swap
    [PSCustomObject]@{Algorithm = "CryptonightuPlexa";     MinMemGB = 2; Command = " --variation 19"} #Cryptonight-uPlexa
    [PSCustomObject]@{Algorithm = "CryptonightTurtle";     MinMemGB = 2; Command = " --variation 20"} #Cryptonight-Turtle
    [PSCustomObject]@{Algorithm = "CryptonightStellite";   MinMemGB = 2; Command = " --variation 21"} #Cryptonight-Stellite
    [PSCustomObject]@{Algorithm = "CryptonightWaltzGraft"; MinMemGB = 2; Command = " --variation 22"} #Cryptonight-WaltzGraft
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands = $Miner_Config.CommonCommands}
else  {$CommonCommands = "--stakjson --no-gpu --auto --no-warmup --low"} #Miner with low priority not to freeze your computer. Has a very small impact on performances. Recommended.

$Devices = @($Devices | Where-Object Type -EQ "CPU")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    if ($Device.CpuFeatures -contains "(x64|aes){2}") {$Miner_Fee = 1.5} else {$Miner_Fee = 3}
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {[math]::Round((Get-CIMInstance -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("variation") -DeviceIDs $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$Command$CommonCommands -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$(if ($Pools.$Algorithm_Norm.SSL) {" -ssl"})$(if ($Pools.$Algorithm_Norm.Name -like "NiceHash*") {" --nicehash"}) --mport $Miner_Port" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "XmRig"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $Miner_Fee / 100}
            }
        } 
    }
}
