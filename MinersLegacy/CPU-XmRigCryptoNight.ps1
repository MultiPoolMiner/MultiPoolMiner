using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\CPU-XmRigCryptoNight\xmrig.exe"
$HashSHA256 = "73C345AB59538A0B4332BA0FB3659F111AAC4291F169D24DA6D5186FEC0B2712"
$Uri = "https://github.com/xmrig/xmrig/releases/download/v2.6.4/xmrig-2.6.4-msvc-win64.zip"
$ManualUri = "https://github.com/xmrig/xmrig"
$Port = "40{0:d2}"

$Commands = [PSCustomObject[]]@(
    #                             Miner algo name            Params         Algorithm_Norm (from Get-Algorithm)
    [PSCustomObject]@{Algorithm = "cryptonight/0";           Params = ""} # CryptoNight    
    [PSCustomObject]@{Algorithm = "cryptonight/1";           Params = ""} # CryptoNightV7
    [PSCustomObject]@{Algorithm = "cryptonight/msr";         Params = ""} # CryptoNightMsr
    [PSCustomObject]@{Algorithm = "cryptonight/rto";         Params = ""} # CryptoNightRto
    [PSCustomObject]@{Algorithm = "cryptonight/xao";         Params = ""} # CryptoNightXao
    [PSCustomObject]@{Algorithm = "cryptonight/xtl";         Params = ""} # CryptoNightXtl
    [PSCustomObject]@{Algorithm = "cryptonight-lite/0";      Params = ""} # CryptoNightLite
    [PSCustomObject]@{Algorithm = "cryptonight-lite/1";      Params = ""} # CryptoNightLiteV7
    [PSCustomObject]@{Algorithm = "cryptonight-heavy";       Params = ""} # CryptoNightHeavy
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/tube";  Params = ""} # CryptoNightHeavyTube
    [PSCustomObject]@{Algorithm = "cryptonight-heavy/xhv";   Params = ""} # CryptoNightHeavyHaven
)

$CommonCommands = ""

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = @($Devices | Where-Object Type -EQ "CPU")

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)    
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $Commands | ForEach-Object {

        $Algorithm = $_.Algorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $Params = $_.Params

        if ($Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" -and $Miner_Device) {
            $ConfigFileName = "$Miner_Name-$($Pools.$Algorithm_Norm.Name)-$($Pools.$Algorithm_Norm.Algorithm).txt"
            $Arguments = [PSCustomObject]@{
                ConfigFile = [PSCustomObject]@{
                    FileName = $ConfigFileName
                    Content = [PSCustomObject]@{
                        "algo"         = $Algorithm
                        "api" = [PSCustomObject]@{
                            "port"         = $Miner_Port
                            "access-token" = $null
                            "worker-id"    = $null
                        }
                        "background"   = $false
                        "cuda-bfactor" = 10
                        "colors"       = $true
                        "donate-level" = 1
                        "log-file"     = $null
                        "print-time"   = 5
                        "retries"      = 5
                        "retry-pause"  = 5
                        "threads"      = @()
                        "pools"        = @([PSCustomObject]@{
                            "keepalive" = $true
                            "nicehash"  = $(if ($Pools.$Algorithm_Norm.Name -eq "Nicehash") {$true} else {$false})
                            "pass"      = "$($Pools.$Algorithm_Norm.Pass)"
                            "url"       = "$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                            "user"      = "$($Pools.$Algorithm_Norm.User)"
                            "rig-id"    = "$WorkerName"
                        })
                    }
                }
                Commands = " --config=$ConfigFileName $Params$CommonCommands"
            }

            [PSCustomObject]@{
                Name       = $Miner_Name
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = $Arguments
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "XmRigCfgFile"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{"$Algorithm_Norm" = 1 / 100}
            }
        }
    }
}
