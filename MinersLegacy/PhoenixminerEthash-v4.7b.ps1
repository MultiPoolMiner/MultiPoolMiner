using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\PhoenixMiner.exe"
$HashSHA256 = "1d3844cf67d147098467e9a7bac34f3ddfc1293e633dc0e3f45bfa586ece302d"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/phoenixminer/PhoenixMiner_4.7b_Windows.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) { $Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*" }

$UnsupportedDriverVersions = @()
$CUDAVersion = ($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation" | Select-Object -Unique).OpenCL.Platform.Version -replace ".*CUDA "
$AMDVersion  = ($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc." | Select-Object -Unique).OpenCL.DriverVersion

if ($UnsupportedDriverVersions -contains $AMDVersion) { 
    Write-Log -Level Warn "Miner ($($Name)) does not support the installed AMD driver version $($AMDVersion). Please use a different AMD driver version. "
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{ Algorithm = "ethash2gb";  MinMemGB = 2; SecondaryAlgorithm = "";        Command = ""; Coin = "" } #Ethash2GB
    [PSCustomObject]@{ Algorithm = "ethash2gb";  MinMemGB = 2; SecondaryAlgorithm = "blake2s"; Command = ""; Coin = "" } #Ethash2GB/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash3gb";  MinMemGB = 3; SecondaryAlgorithm = "";        Command = ""; Coin = "" } #Ethash3GB
    [PSCustomObject]@{ Algorithm = "ethash3gb";  MinMemGB = 3; SecondaryAlgorithm = "blake2s"; Command = ""; Coin = "" } #Ethash3GB/Blake2s
    [PSCustomObject]@{ Algorithm = "ethash";     MinMemGB = 4; SecondaryAlgorithm = "";        Command = ""; Coin = "" } #Ethash
    [PSCustomObject]@{ Algorithm = "ethash";     MinMemGB = 4; SecondaryAlgorithm = "blake2s"; Command = ""; Coin = "" } #Ethash/Blake2s
    [PSCustomObject]@{ Algorithm = "progpow2gb"; MinMemGB = 2; SecondaryAlgorithm = "";        Command = ""; Coin = " -coin bci" } #Progpow2GB
    [PSCustomObject]@{ Algorithm = "progpow3gb"; MinMemGB = 3; SecondaryAlgorithm = "";        Command = ""; Coin = " -coin bci" } #Progpow3GB
    [PSCustomObject]@{ Algorithm = "progpow";    MinMemGB = 4; SecondaryAlgorithm = "";        Command = ""; Coin = " -coin bci" } #Progpow
    [PSCustomObject]@{ Algorithm = "Ubqhash2GB"; MinMemGB = 4; SecondaryAlgorithm = "";        Command = ""; Coin = " -coin ubq" } #Ubqhash2GB
    [PSCustomObject]@{ Algorithm = "Ubqhash3GB"; MinMemGB = 4; SecondaryAlgorithm = "";        Command = ""; Coin = " -coin ubq" } #Ubqhash3GB
    [PSCustomObject]@{ Algorithm = "Ubqhash";    MinMemGB = 4; SecondaryAlgorithm = "";        Command = ""; Coin = " -coin ubq" } #Ubqhash
)
#Commands from config file take precedence
if ($Miner_Config.Commands) { $Miner_Config.Commands | ForEach-Object { $Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object { $_.Algorithm -ne $Algorithm }; $Commands += $_ } }

$SecondaryAlgoIntensities = [PSCustomObject]@{ 
    "blake2s" = @(30, 60, 90, 120)
}
#Intensities from config file take precedence
$Miner_Config.SecondaryAlgoIntensities.PSObject.Properties.Name | Select-Object | ForEach-Object { 
    $SecondaryAlgoIntensities | Add-Member $_ $Miner_Config.SecondaryAlgoIntensities.$_ -Force
 }

$Commands | ForEach-Object { 
    if ($_.SecondaryAlgorithm) { 
        $Command = $_
        $SecondaryAlgoIntensities.$($_.SecondaryAlgorithm) | Select-Object | ForEach-Object { 
            if ($null -ne $Command.SecondaryAlgoIntensity) { 
                $Command = ($Command | ConvertTo-Json | ConvertFrom-Json)
                $Command | Add-Member SecondaryAlgoIntensity ([String] $_) -Force
                $Commands += $Command
            }
            else { $Command | Add-Member SecondaryAlgoIntensity $_ }
        }
    }
}

#CommonCommandsAll from config file take precedence
if ($Miner_Config.CommonCommandsAll) { $CommonCommandsAll = $Miner_Config.CommonCommandsAll }
else { $CommonCommandsAll = " -log 0 -wdog 0 -mclock 0 -rvram -1 -eres 0" }

#CommonCommandsNvidia from config file take precedence
if ($Miner_Config.CommonCommandsNvidia) { $CommonCommandsNvidia = $Miner_Config.CommonCommandsNvidia }
else { $CommonCommandsNvidia = " -mi 14 -nvidia" }

#CommonCommandsAmd from config file take precedence
if ($Miner_Config.CommonCommandsAmd) { $CommonCommmandAmd = $Miner_Config.CommonCommandsAmd }
else { $CommonCommandsAmd = " -amd" }

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object { $UnsupportedDriverVersions -notcontains $_.OpenCL.DriverVersion })
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object { 
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    switch ($_.Vendor) { 
        "Advanced Micro Devices, Inc." { $CommonCommands = $CommonCommandsAmd + $CommonCommandsAll }
        "NVIDIA Corporation" { $CommonCommands = $CommonCommandsNvidia + $CommonCommandsAll }
        Default { $CommonCommands = $CommonCommandsAll }
    }

    $Commands | ForEach-Object { $Algorithm_Norm = Get-Algorithm $_.Algorithm; $_ } | Where-Object { $Pools.$Algorithm_Norm.Host } | ForEach-Object { 
        $Arguments_Primary = ""
        $Arguments_Secondary = ""
        $MinMemGB = $_.MinMemGB
        $TurboKernel = ""
        
        if ($Miner_Device = @($Device | Where-Object { ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB })) { 
            if ($_.Coin) { $Coin = $_.Coin }
            else { 
                switch ($Pools.$Algorithm_Norm.CoinName) { #Ethash coin to use for devfee to avoid switching DAGs
                    "Akroma"          { $Coin = " -coin akroma" }
                    "Atheios"         { $Coin = " -coin ath" } 
                    "Aura"            { $Coin = " -coin aura" }
                    "Bitcoin2Gen"     { $Coin = " -coin b2g" }
                    "BitcoinInterest" { $Coin = " -coin bci" }
                    "Callisto"        { $Coin = " -coin clo" }
                    "DubaiCoin"       { $Coin = " -coin dbix" }
                    "Ellaism"         { $Coin = " -coin ella" }
                    "Ether1"          { $Coin = " -coin etho" } 
                    "EtherCC"         { $Coin = " -coin etcc" } 
                    "EtherGem"        { $Coin = " -coin egem" }
                    "Ethersocial"     { $Coin = " -coin esn" }
                    "EtherZero"       { $Coin = " -coin etz" }
                    "Ethereum"        { $Coin = " -coin eth" }
                    "EthereumClassic" { $Coin = " -coin etc" }
                    "Expanse"         { $Coin = " -coin exp" }
                    "Genom"           { $Coin = " -coin gen" }
                    "HotelbyteCoin"   { $Coin = " -coin hbc" }
                    "Metaverse"       { $Coin = " -coin etp" }
                    "Mix"             { $Coin = " -coin mix" } 
                    "Moac"            { $Coin = " -coin moac" }
                    "Musicoin"        { $Coin = " -coin music" }
                    "Nekonium"        { $Coin = " -coin nuko" }
                    "Pegascoin"       { $Coin = " -coin pgc" }
                    "Progpow"         { $Coin = " -coin bci" }
                    "Pirl"            { $Coin = " -coin pirl" } 
                    "Reosc"           { $Coin = " -coin reosc" } 
                    "Ubiq"            { $Coin = " -coin ubq" }
                    "Victorium"       { $Coin = " -coin vic" }
                    "WhaleCoin"       { $Coin = " -coin whale" }
                    "Yocoin"          { $Coin = " -coin yoc" }
                    default           { $Coin = " -coin auto" }
                }
            }

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -DeviceIDs $Miner_Device.Type_Vendor_Index

            if ($null -ne $_.SecondaryAlgoIntensity) { 
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object { $Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm" }) + @("$Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @($_.SecondaryAlgoIntensity) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week }

                $Arguments_Secondary += " -dcoin $Secondary_Algorithm -dpool $(if ($Pools.$Secondary_Algorithm_Norm.SSL) { "ssl://" })$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpass $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryAlgoIntensity -ge 0){ " -sci $($_.SecondaryAlgoIntensity)" })"
                $Miner_Fees = [PSCustomObject]@{ $Algorithm_Norm = 0.9 / 100; $Secondary_Algorithm_Norm = 0 / 100 }

                $IntervalMultiplier = 2
                $WarmupTime = 60
            }
            else { 
                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object { $Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm" }) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{ $Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                $Arguments_Primary += " -gt 0" #Enable auto-tuning
                
                $WarmupTime = 45
                $Miner_Fees = [PSCustomObject]@{ "$Algorithm_Norm" = 0.65 / 100 }

                #TurboKernels
                if ($Miner_Device.Vendor -eq "Advanced Micro Devices, Inc." -and ([math]::Round((10 * ($Miner_Device.OpenCL | Measure-Object GlobalMemSize -Minimum).Minimum / 1GB), 0) / 10) -ge (2 * $MinMemGB)) { 
                    # faster AMD "turbo" kernels require twice as much VRAM
                    $TurboKernel = " -clkernel 3"
                }
            }

            if ($null -eq $_.SecondaryAlgoIntensity -or $Pools.$Secondary_Algorithm_Norm.Host) { 
                [PSCustomObject]@{ 
                    Name               = $Miner_Name
                    BaseName           = $Miner_BaseName
                    Version            = $Miner_Version
                    DeviceName         = $Miner_Device.Name
                    Path               = $Path
                    HashSHA256         = $HashSHA256
                    Arguments          = ("$Command$CommonCommands$Coin -mport -$Miner_Port$(if(($Pools.$Algorithm_Norm.Name -like "NiceHash*" -or $Pools.$Algorithm_Norm.Name -like "MiningPoolHub*") -and $Algorithm_Norm -like "Ethash*") { " -proto 4" }) -pool $(if ($Pools.$Algorithm_Norm.SSL) { "ssl://" })$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass)$Arguments_Primary$Arguments_Secondary$TurboKernel -gpus $(($Miner_Device | ForEach-Object { '{0:x}' -f ($_.Type_PlatformId_Slot + 1) }) -join ',')" -replace "\s+", " ").trim()
                    HashRates          = $Miner_HashRates
                    API                = "Claymore"
                    Port               = $Miner_Port
                    URI                = $Uri
                    Fees               = $Miner_Fees
                    IntervalMultiplier = $IntervalMultiplier
                    WarmupTime         = $WarmupTime #seconds
                }
            }
        }
    }
}
