using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\jce_cn_gpu_miner64.exe"
$HashSHA256 = "9EC1A55DA073798690C9A3785489E8A01613A2839DE56D889F2267CCAF82DF9B"
$Uri = "https://github.com/jceminer/cn_gpu_miner/raw/master/jce_cn_gpu_miner.033b6.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=3281187.0"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Variation = 1;  Algorithm_Norm = "Cryptonight";           MinMemGB = 2; Fee = 0.9; Params = ""} #Original Cryptolight
    [PSCustomObject]@{Variation = 3;  Algorithm_Norm = "CryptonightV7";         MinMemGB = 2; Fee = 0.9; Params = ""} #Cryptonight V7 fork of April-2018
    [PSCustomObject]@{Variation = 4;  Algorithm_Norm = "CryptolightV7";         MinMemGB = 1; Fee = 0.9; Params = ""} #Cryptolight V7 fork of April-2018
    [PSCustomObject]@{Variation = 5;  Algorithm_Norm = "CryptonightHeavy";      MinMemGB = 4; Fee = 2.1; Params = ""} #Cryptonight-Heavy
    [PSCustomObject]@{Variation = 6;  Algorithm_Norm = "CryptonightLiteIpbc";   MinMemGB = 1; Fee = 0.9; Params = ""} #Cryptolight-IPBC
    [PSCustomObject]@{Variation = 7;  Algorithm_Norm = "CryptonightXtl";        MinMemGB = 2; Fee = 0.9; Params = ""} #Cryptonight-XTL fork of May-2018
    [PSCustomObject]@{Variation = 8;  Algorithm_Norm = "CryptonightXao";        MinMemGB = 2; Fee = 0.9; Params = ""} #Cryptonight-Alloy
    [PSCustomObject]@{Variation = 9;  Algorithm_Norm = "CryptonightMarketCash"; MinMemGB = 2; Fee = 0.9; Params = ""} #Cryptonight-MKT
    [PSCustomObject]@{Variation = 10; Algorithm_Norm = "CryptonightRto";        MinMemGB = 2; Fee = 0.9; Params = ""} #Cryptonight-Arto
    [PSCustomObject]@{Variation = 11; Algorithm_Norm = "CryptonightFast";       MinMemGB = 2; Fee = 0.9; Params = ""} #Cryptonight-Fast MSR fork of June-2018
    [PSCustomObject]@{Variation = 12; Algorithm_Norm = "CryptonightHeavyHaven"; MinMemGB = 4; Fee = 2.1; Params = ""} #Cryptonight-Haven fork of June-2018
    [PSCustomObject]@{Variation = 13; Algorithm_Norm = "CryptonightHeavyTube";  MinMemGB = 4; Fee = 2.1; Params = ""} #Cryptonight-BitTube v2 of July-2018
    [PSCustomObject]@{Variation = 14; Algorithm_Norm = "CryptonightRed";        MinMemGB = 1; Fee = 0.9; Params = ""} #Cryptonight-Red
    [PSCustomObject]@{Variation = 15; Algorithm_Norm = "CryptonightV8";         MinMemGB = 2; Fee = 0.9; Params = ""} #Cryptonight V8 fork of October-2018
    #[PSCustomObject]@{Variation = 16; Algorithm_Norm = "_AUTO_";                MinMemGB = 2; Fee = 0;   Params = ""} #Pool-selected autoswitch, not supported by MPM
    [PSCustomObject]@{Variation = 17; Algorithm_Norm = "CryptonightDark";       MinMemGB = 1; Fee = 0.9; Params = ""} #Cryptonight-Dark
)
$CommonCommands = " --no-warmup --low" #Miner with low priority not to freeze your computer. Has a very small impact on performances. Recommended.

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)
                
    $Commands | ForEach-Object {
        $Algorithm_Norm = $_.Algorithm_Norm
        $Params = $_.Params
        $Fee = $_.Fee
        $MinMemGB = $_.MinMemGB
        $Variation = $_.Variation

        $Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            if ($Config.UseDeviceNameForStatsFileNaming) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            }

            #Get Params for active miner devices
            $Params = Get-CommandPerDevice $Params $Miner_Device.Type_Vendor_Index

            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("--no-cpu --auto --variation $Variation -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$(if ($Pools.$Algorithm_Norm.SSL) {" -ssl"})$(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") {" --nicehash"}) --mport $Miner_Port -g $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_PlatformId_Index)}) -join ',')$Params$CommonCommands" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "JceMiner"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = $Fee / 100}
            }
        } 
    }
}
