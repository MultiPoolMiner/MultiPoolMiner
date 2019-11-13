using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\miner.exe"
$HashSHA256 = "C3CB1770B93611F45CC194DF11188E56ACE58DD718F5E4260C3ED65EABB1F6B7"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/EWBF2/EWBF.Equihash.miner.v0.6.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"

$Miner_Config = Get-MinerConfig -Name $Name -Config $Config

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "Equihash965";  MinMemGB = 1.8; Command = " --algo 96_5" }
    # [PSCustomObject]@{ Algorithm = "Equihash1445"; MinMemGB = 1.7; Command = " --algo 144_5" } # Gminer 1.55 & MiniZ 1.5p is faster
    # [PSCustomObject]@{ Algorithm = "Equihash1927"; MinMemGB = 2.7; Command = " --algo 192_7" } # Gminer 1.55 & MiniZ 1.5p is faster
    [PSCustomObject]@{ Algorithm = "Equihash2109"; MinMemGB = 1.3; Command = " --algo 210_9" }
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) { $CommonCommands = $Miner_Config.CommonCommands }
else { $CommonCommands = " --pec --intensity 64 --eexit 1" }

$Devices = $Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA"
$Devices | Select-Object Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = [UInt16]($Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Id) + 1)

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> } | ForEach-Object { 
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object { $([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            $Miner_Name = (@($Name) + @($Miner_Device.Model | Sort-Object -unique | ForEach-Object { $Model = $_; "$(@($Miner_Device | Where-Object Model -eq $Model).Count)x$Model" }) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

            if ($Algorithm_Norm -eq "Equihash1445") { 
                #define --pers for equihash1445
                $AlgoPers = " --pers $(Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default 'auto')"
            }
            else { $AlgoPers = "" }

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) { $Miner_Config = [PSCustomObject]@{ DisableDevFeeMining = $Config.DisableDevFeeMining } }
            if ($Miner_Config.DisableDevFeeMining) { 
                $NoFee = " --fee 0"
                $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 0 / 100 }
            }
            else { 
                $NoFee = ""
                $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 2 / 100 }
            }

            if ($Algorithm_Norm -ne "Equihash1445" -or $AlgoPers) { 
                [PSCustomObject]@{ 
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    Path             = $Path
                    HashSHA256       = $HashSHA256
                    Arguments        = ("$Command$CommonCommands$AlgoPers --api 127.0.0.1:$($Miner_Port) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass)$NoFee --cuda_devices $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_Vendor_Index) }) -join ' ')" -replace "\s+", " ").trim()
                    HashRates        = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                    API              = "DSTM"
                    Port             = $Miner_Port
                    URI              = $Uri
                    Fees             = $Miner_Fees
                    PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                }
            }
        }
    }
}
