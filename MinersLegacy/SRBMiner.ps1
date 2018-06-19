using module ..\Include.psm1

$Path = ".\Bin\AMD-SRBMiner\SRBMiner-CN.exe"
$HashSHA256 = "095C01843E94C7836672992FE00D71984A28AF546CD6063C7AE996B36260F7C6"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/SRBMiner/SRBMiner-CN-V1-6-0.zip"
$UriManual = "https://bitcointalk.org/index.php?topic=3167363.0"
$MinerFeeInPercent = 0.85

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = "52{0:d2}"
                
# Commands are case sensitive!
$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit [AlgorithmName]_config.txt in the miner binary 
    [PSCustomObject]@{Algorithm = "alloy"     ; Threads = 1; Params = @()} # CryptoNight-Alloy 1 thread
    [PSCustomObject]@{Algorithm = "artocash"  ; Threads = 1; Params = @()} # CryptoNight-ArtoCash 1 thread
    [PSCustomObject]@{Algorithm = "b2n"       ; Threads = 1; Params = @()} # CryptoNight-B2N 1 thread
    [PSCustomObject]@{Algorithm = "fast"      ; Threads = 1; Params = @()} # CryptoNight-Fast (Masari) 1 thread
    [PSCustomObject]@{Algorithm = "lite"      ; Threads = 1; Params = @()} # CryptoNight-Lite 1 thread
    [PSCustomObject]@{Algorithm = "haven"     ; Threads = 1; Params = @()} # CryptoNight-Haven 1 thread
    [PSCustomObject]@{Algorithm = "heavy"     ; Threads = 1; Params = @()} # CryptoNight-Heavy 1 thread
    [PSCustomObject]@{Algorithm = "ipbc"      ; Threads = 1; Params = @()} # CryptoNight-PPBC 1 thread
    [PSCustomObject]@{Algorithm = "marketcash"; Threads = 1; Params = @()} # CryptoNight-MarketCash 1 thread
    [PSCustomObject]@{Algorithm = "normalv7"  ; Threads = 1; Params = @()} # CryptoNightV7 1 thread
    [PSCustomObject]@{Algorithm = "stellitev4"; Threads = 1; Params = @()} # CryptoNight-Stellite 1 thread
    [PSCustomObject]@{Algorithm = "alloy"     ; Threads = 2; Params = @()} # CryptoNight-Alloy 2 threads
    [PSCustomObject]@{Algorithm = "artocash"  ; Threads = 2; Params = @()} # CryptoNight-ArtoCash 2 threads
    [PSCustomObject]@{Algorithm = "b2n"       ; Threads = 2; Params = @()} # CryptoNight-B2N 2 threads
    [PSCustomObject]@{Algorithm = "fast"      ; Threads = 2; Params = @()} # CryptoNight-Fast (Masari) 2 threads
    [PSCustomObject]@{Algorithm = "lite"      ; Threads = 2; Params = @()} # CryptoNight-Lite 2 threads
    [PSCustomObject]@{Algorithm = "heavy"     ; Threads = 2; Params = @()} # CryptoNight-Heavy 2 threads
    [PSCustomObject]@{Algorithm = "haven"     ; Threads = 2; Params = @()} # CryptoNight-Haven 2 threads
    [PSCustomObject]@{Algorithm = "ipbc"      ; Threads = 2; Params = @()} # CryptoNight-PPBC 2 threads
    [PSCustomObject]@{Algorithm = "marketcash"; Threads = 2; Params = @()} # CryptoNight-MarketCash 2 threads
    [PSCustomObject]@{Algorithm = "normalv7"  ; Threads = 2; Params = @()} # CryptoNightV7 2 thread
    [PSCustomObject]@{Algorithm = "stellitev4"; Threads = 1; Params = @()} # CryptoNight-Stellite 2 threads
    #[PSCustomObject]@{Algorithm = "normal"    ; Threads = 1; Params = @()} # CryptoNight 1 thread, ASIC territory
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm "cryptonight-$($Algorithm)"
        $Threads = $_.Threads
        $Params = $_.Params
        $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

        $ConfigFile = "$($Miner_Name)-$($Algorithm)-Port$($Miner_Port).json"
      
        (
            [PSCustomObject]@{
                api_enabled      = $true
                api_port         = [Int]$Miner_Port
                api_rig_name     = "$($Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker)"
                cryptonight_type = $Algorithm
                gpu_conf         = @($Miner_Device.Type_PlatformId_Index | Foreach-Object {
                    [PSCustomObject]@{
                        "id"        = $_  
                        "intensity" = 0
                        "threads"   = [Int]$Threads
                        #"worksize"  = 8
                    }
                })
            } | ConvertTo-Json -Depth 10
        ) | Set-Content "$(Split-Path $Path)\$($ConfigFile)" -ErrorAction Ignore

        [PSCustomObject]@{
            Name       = $Miner_Name
            DeviceName = $Miner_Device.Name
            Path       = $Path
            HashSHA256 = $HashSHA256
            Arguments  = "--config $ConfigFile --cpool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --cwallet $($Pools.$Algorithm_Norm.User) --cpassword $($Pools.$Algorithm_Norm.Pass) --ctls $($Pools.$Algorithm_Norm.SSL) --cnicehash $($Pools.$Algorithm_Norm.Name -eq 'NiceHash')$Params$CommonCommands"
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "SRBMiner"
            Port       = $Miner_Port
            URI        = $Uri
            Fees       = [PSCustomObject]@{"$Algorithm_Norm" = $MinerFeeInPercent / 100}
        }
    }
}
