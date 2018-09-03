using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\AMD-XmRig-Cryptonight\xmrig-amd.exe"
$HashSHA256 = "5905924C61D96267C176BC9AF86C16DCC837B81378E47315231A9EE0C5CC48B7"
$Uri = "https://github.com/xmrig/xmrig-amd/releases/download/v2.7.3-beta/xmrig-amd-2.7.3-beta-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig-amd"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    #                             Miner algo name            MinMem        Params         Algorithm_Norm (from Get-Algorithm)
    [PSCustomObject]@{Algorithm = "cryptonight/0";           MinMemGB = 2; Params = ""} # CryptoNight    
    [PSCustomObject]@{Algorithm = "cryptonight/1";           MinMemGB = 2; Params = ""} # CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight/msr";         MinMemGB = 2; Params = ""} # CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight/rto";         MinMemGB = 2; Params = ""} # CryptoNightRto
    [PSCustomObject]@{Algorithm = "cryptonight/xao";         MinMemGB = 2; Params = ""} # CryptoNightXao
    [PSCustomObject]@{Algorithm = "cryptonight/xtl";         MinMemGB = 2; Params = ""} # CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight-lite/0";      MinMemGB = 1; Params = ""} # CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight-lite/1";      MinMemGB = 1; Params = ""} # CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight-heavy";       MinMemGB = 4; Params = ""} # CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/tube";  MinMemGB = 4; Params = ""} # CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/xhv";   MinMemGB = 4; Params = ""} # CryptoNightHeavyHaven
)

$CommonCommands = ""

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc.")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)    

    $Commands | ForEach-Object {

        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params
        
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1000000000)})
        
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

        if ($Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" -and $Miner_Device) {
            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    "algo"            = $Algorithm
                    "api" = [PSCustomObject]@{
                        "port"         = $Miner_Port
                        "access-token" = $null
                        "worker-id"    = $null
                    }
                    "background"      = $false
                    "cache"           = $true
                    "colors"          = $true
                    "donate-level"    = 1
                    "log-file"        = $null
                    "print-time"      = 5
                    "retries"         = 5
                    "retry-pause"     = 5
                    "opencl-platform" = $Miner_Device.PlatformId
                    "pools"        = @([PSCustomObject]@{
                        "keepalive" = $true
                        "nicehash"  = $(if ($Pools.$Algorithm_Norm.Name -eq "Nicehash") {$true} else {$false})
                        "pass"      = "$($Pools.$Algorithm_Norm.Pass)"
                        "url"       = "$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                        "user"      = "$($Pools.$Algorithm_Norm.User)"
                        "rig-id"    = "$WorkerName"
                    })
                    "threads" = @($Miner_Device.Type_PlatformId_Index | Foreach-Object {
                        [PSCustomObject]@{
                            "affine_to_cpu" = $false
                            "comp_mode"     = $true
                            "index"         = $_
                            "intensity"     = 768
                            "mem_chunk"     = 2
                            "strided_index" = 1
                            "worksize"      = [Int]8
                        }
                    })
                }
                Commands = "$Params$CommonCommands"
            }

            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Arguments
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "XmRig"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
            }
        }
    }
}