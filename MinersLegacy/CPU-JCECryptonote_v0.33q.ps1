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

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        #Unprofitable [PSCustomObject]@{Variation = 1;  Algorithm = "Cryptonight";           MinMemGB = 2; Params = ""} #Original Cryptonight
        #Unprofitable [PSCustomObject]@{Variation = 2;  Algorithm = "Cryptolight";           MinMemGB = 1; Params = ""} #Original Cryptolight
        #Unprofitable [PSCustomObject]@{Variation = 3;  Algorithm = "CryptonightV7";         MinMemGB = 2; Params = ""} #Cryptonight V7 fork of April-2018
        #Unprofitable [PSCustomObject]@{Variation = 4;  Algorithm = "CryptolightV7";         MinMemGB = 15; Params = ""} #Cryptolight V7 fork of April-2018
        [PSCustomObject]@{Variation = 5;  Algorithm = "CryptonightHeavy";      MinMemGB = 4; Params = ""} #Cryptonight-Heavy
        [PSCustomObject]@{Variation = 6;  Algorithm = "CryptonightLiteIpbc";   MinMemGB = 1; Params = ""} #Cryptolight-IPBC
        [PSCustomObject]@{Variation = 7;  Algorithm = "CryptonightXtl";        MinMemGB = 2; Params = ""} #Cryptonight-XTL fork of May-2018
        [PSCustomObject]@{Variation = 8;  Algorithm = "CryptonightXao";        MinMemGB = 2; Params = ""} #Cryptonight-Alloy
        [PSCustomObject]@{Variation = 9;  Algorithm = "CryptonightRto";        MinMemGB = 2; Params = ""} #Cryptonight-Arto
        [PSCustomObject]@{Variation = 11; Algorithm = "CryptonightFast";       MinMemGB = 2; Params = ""} #Cryptonight-Fast MSR fork of June-2018
        [PSCustomObject]@{Variation = 12; Algorithm = "CryptonightHeavyHaven"; MinMemGB = 4; Params = ""} #Cryptonight-Haven fork of June-2018
        [PSCustomObject]@{Variation = 13; Algorithm = "CryptonightHeavyTube";  MinMemGB = 4; Params = ""} #Cryptonight-BitTube v2 of July-2018
        [PSCustomObject]@{Variation = 14; Algorithm = "CryptonightRed";        MinMemGB = 1; Params = ""} #Cryptonight-Red
        [PSCustomObject]@{Variation = 15; Algorithm = "CryptonightV8";         MinMemGB = 2; Params = ""} #Cryptonight V8 fork of October-2018
        #[PSCustomObject]@{Variation = 16; Algorithm = "_AUTO_";                MinMemGB = 2;   Params = ""} #Pool-selected autoswitch, not supported by MPM
        [PSCustomObject]@{Variation = 17; Algorithm = "CryptonightDark";       MinMemGB = 1; Params = ""} #Cryptonight-Dark
        [PSCustomObject]@{Variation = 18; Algorithm = "CryptonightSwap";       MinMemGB = 2; Params = ""} #Cryptonight-Swap
        [PSCustomObject]@{Variation = 19; Algorithm = "CryptonightuPlexa";     MinMemGB = 2; Params = ""} #Cryptonight-uPlexa
        [PSCustomObject]@{Variation = 20; Algorithm = "CryptonightTurtle";     MinMemGB = 2; Params = ""} #Cryptonight-Turtle
        [PSCustomObject]@{Variation = 21; Algorithm = "CryptonightStellite";   MinMemGB = 2; Params = ""} #Cryptonight-Stellite
        [PSCustomObject]@{Variation = 22; Algorithm = "CryptonightWaltzGraft"; MinMemGB = 2; Params = ""} #Cryptonight-WaltzGraft
    )
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters = $Miner_Config.CommonParameters}
else  {$CommonParameters = " --no-warmup --low"} #Miner with low priority not to freeze your computer. Has a very small impact on performances. Recommended.

$Devices = @($Devices | Where-Object Type -EQ "CPU")
$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    if ($Device.CpuFeatures -contains "(x64|aes){2}") {$Miner_Fee = 1.5} else {$Miner_Fee = 3}
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1
    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Host} | ForEach-Object {
        $Fee = $_.Fee
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters
        $Variation = $_.Variation
        

        if ($Miner_Device = @($Device | Where-Object {[math]::Round((Get-CIMInstance -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'

            #Get Params for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$Algorithm_Norm $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("--stakjson --no-gpu --auto --variation $Variation -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$(if ($Pools.$Algorithm_Norm.SSL) {" -ssl"})$(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") {" --nicehash"}) --mport $Miner_Port$Parameters$CommonParameters" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "XmRig"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $Miner_Fee / 100}
            }
        } 
    }
}
