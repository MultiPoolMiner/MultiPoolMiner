using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\AMD-SRBMiner-CryptoNight\SRBMiner-CN.exe"
$HashSHA256 = "5754439C2AE8331F75BDA10F14DBAEAF4F5948F391E2CF35AAFD585CAA4E0973"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/SRBMiner/SRBMiner-CN-V1-6-5.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3167363.0"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = "40{0:d2}"
                
# Algorithm names are case sensitive!
$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit Config_[MinerName]-[Algorithm]-[Port].txt in the miner binary directory 
    [PSCustomObject]@{Algorithm = "alloy";      Threads = 1; MinMemGb = 2} # CryptoNightXao 1 thread
    [PSCustomObject]@{Algorithm = "artocash";   Threads = 1; MinMemGb = 2} # CryptoNightRto 1 thread
    [PSCustomObject]@{Algorithm = "b2n";        Threads = 1; MinMemGb = 2} # CryptoNightB2N 1 thread
    [PSCustomObject]@{Algorithm = "bittubev2";  Threads = 1; MinMemGb = 4} # CryptoNightHeavyTube 1 thread
    [PSCustomObject]@{Algorithm = "fast";       Threads = 1; MinMemGb = 2} # CryptoNightFast 1 thread
    [PSCustomObject]@{Algorithm = "lite";       Threads = 1; MinMemGb = 1} # CryptoNightLite 1 thread
    [PSCustomObject]@{Algorithm = "liteV7";     Threads = 1; MinMemGb = 1} # CryptoNightLiteV7 1 thread
    [PSCustomObject]@{Algorithm = "haven";      Threads = 1; MinMemGb = 4} # CryptoNightHeavyHaven 1 thread
    [PSCustomObject]@{Algorithm = "heavy";      Threads = 1; MinMemGb = 4} # CryptoNightHeavy 1 thread
    [PSCustomObject]@{Algorithm = "marketcash"; Threads = 1; MinMemGb = 2} # CryptoNightMarketCash 1 thread
    [PSCustomObject]@{Algorithm = "normalv7";   Threads = 1; MinMemGb = 2} # CryptoNightV7 1 thread
    [PSCustomObject]@{Algorithm = "stellitev4"; Threads = 1; MinMemGb = 2} # CryptoNightXtl 1 thread
    [PSCustomObject]@{Algorithm = "alloy";      Threads = 2; MinMemGb = 2} # CryptoNightXao 2 threads
    [PSCustomObject]@{Algorithm = "artocash";   Threads = 2; MinMemGb = 2} # CryptoNightRto 2 threads
    [PSCustomObject]@{Algorithm = "b2n";        Threads = 2; MinMemGb = 2} # CryptoNightB2N 2 threads
    [PSCustomObject]@{Algorithm = "bittubev2";  Threads = 2; MinMemGb = 4} # CryptoNightHeavyTube 2 threads
    [PSCustomObject]@{Algorithm = "fast";       Threads = 2; MinMemGb = 2} # CryptoNightFast 2 threads
    [PSCustomObject]@{Algorithm = "lite";       Threads = 2; MinMemGb = 1} # CryptoNightLite 2 threads
    [PSCustomObject]@{Algorithm = "liteV7";     Threads = 2; MinMemGb = 1} # CryptoNightLiteV7 2 threads
    [PSCustomObject]@{Algorithm = "haven";      Threads = 2; MinMemGb = 4} # CryptoNightHeavyHaven 2 threads
    [PSCustomObject]@{Algorithm = "heavy";      Threads = 2; MinMemGb = 4} # CryptoNightHeavy 2 threads
    [PSCustomObject]@{Algorithm = "marketcash"; Threads = 2; MinMemGb = 2} # CryptoNightMarketCash 2 threads
    [PSCustomObject]@{Algorithm = "normalv7";   Threads = 2; MinMemGb = 2} # CryptoNightV7 2 threads
    [PSCustomObject]@{Algorithm = "stellitev4"; Threads = 2; MinMemGb = 2} # CryptoNightXtl 2 threads

    # Asic only (2018/07/12)
    #[PSCustomObject]@{Algorithm = "normal";     Threads = 1; MinMemGb = 2} # CryptoNight 1 thread
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc."

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm "cryptonight$($Algorithm)"
        $Threads = $_.Threads
        $MinMemGb = $_.MinMemGb

        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1000000000)})
        $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object ) | Select-Object) -join '-'

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
        
            $Arguments = @(
                [PSCustomObject]@{
                    Config = [PSCustomObject]@{
                        api_enabled      = $true
                        api_port         = [Int]$Miner_Port
                        api_rig_name     = "$($Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker)"
                        cryptonight_type = $Algorithm
                        intensity        = 0
                        double_threads   = $false
                        gpu_conf         = @($Miner_Device.Type_PlatformId_Index | Foreach-Object {
                            [PSCustomObject]@{
                                "id"        = $_  
                                "intensity" = 0
                                "threads"   = [Int]$Threads
                                "platform"  = "OpenCL"
                                #"worksize"  = [Int]8
                            }
                        })
                    }
                }
                [PSCustomObject]@{
                    Pools = [PSCustomObject]@{
                        pools = @([PSCustomObject]@{
                            pool = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                            wallet = $($Pools.$Algorithm_Norm.User)
                            password = $($Pools.$Algorithm_Norm.Pass)
                            pool_use_tls = $($Pools.$Algorithm_Norm.SSL)
                            nicehash = $($Pools.$Algorithm_Norm.Name -eq 'NiceHash')
                        })
                    }
                }
            )

            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Arguments
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "SRBMiner"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{"$Algorithm_Norm" = 0.85 / 100}
            }
        }
    }
}