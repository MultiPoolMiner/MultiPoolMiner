using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\PhoenixMiner.exe"
$HashSHA256 = "1127E17A633C30C635527AB65CDD408B828A89FB154CB17580E3F1F1B3E87992"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/phoenixminer/PhoenixMiner_4.2c_Windows.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$UnsupportedDriverVersions = @("2841.5", "2841.19")
$CUDAVersion = ($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation" | Select-Object -Unique).OpenCL.Platform.Version -replace ".*CUDA "
$AMDVersion  = ($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "Advanced Micro Devices, Inc." | Select-Object -Unique).OpenCL.DriverVersion

if ($UnsupportedDriverVersions -contains $AMDVersion) {
    Write-Log -Level Warn "Miner ($($Name)) does not support the installed AMD driver version $($AMDVersion). Please update your AMD drivers. "
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    #DualMining does not work with 4.0b
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash2GB
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 30;  Params = ""} #Ethash2gb/Blake2s30
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Blake2s60
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 90;  Params = ""} #Ethash2gb/Blake2s90
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 120; Params = ""} #Ethash2gb/Blake2s120
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash3GB
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 30;  Params = ""} #Ethash3gb/Blake2s30
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Blake2s60
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 90;  Params = ""} #Ethash3gb/Blake2s90
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 120; Params = ""} #Ethash3gb/Blake2s120
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 30;  Params = ""} #Ethash/Blake2s30
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash/Blake2s60
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 90;  Params = ""} #Ethash/Blake2s90
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 120; Params = ""} #Ethash/Blake2s120
    )
}

#CommonCommandsAll from config file take precedence
if ($Miner_Config.CommonParametersAll) {$CommonParametersAll = $Miner_Config.CommonParametersAll}
else {$CommonParametersAll = " -log 0 -wdog 0"}

#CommonCommandsNvidia from config file take precedence
if ($Miner_Config.CommonParametersNvidia) {$CommonParametersNvidia = $Miner_Config.CommonParametersNvidia}
else {$CommonParametersNvidia = " -mi 14 -nvidia"}

#CommonCommandsAmd from config file take precedence
if ($Miner_Config.CommonParametersAmd) {$CommonCommmandAmd = $Miner_Config.CommonParametersAmd}
else {$CommonParametersAmd = " -amd"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object {$UnsupportedDriverVersions -notcontains $_.OpenCL.DriverVersion})
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {$CommonParameters = $CommonParametersAmd + $CommonParametersAll}
        "NVIDIA Corporation" {$CommonParameters = $CommonParametersNvidia + $CommonParametersAll}
        Default {$CommonParameters = $CommonParametersAll}
    }

    $Commands | ForEach-Object {$Main_Algorithm_Norm = Get-Algorithm $_.MainAlgorithm; $_} | Where-Object {$Pools.$Main_Algorithm_Norm.Host} | ForEach-Object {
        $Main_Algorithm = $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters
        $TurboKernel = ""
        $Arguments_Primary = ""
        $Arguments_Secondary = ""
        
        #define -coin parameter for bci or ubq
        switch ($Main_Algorithm_Norm) {
            "ProgPOW" {$Arguments_Primary = " -coin bci"}
            "Ubqhash" {$Arguments_Primary = " -coin ubq"}
        }
        switch ($Pools.$Main_Algorithm_Norm.CoinName) {#Ethash coin to use for devfee to avoid switching DAGs
            "Akroma"          {$Coin = " -coin akroma"}
            "Atheios"         {$Coin = " -coin ath"} 
            "Aura"            {$Coin = " -coin aura"}
            "Bitcoin2Gen"     {$Coin = " -coin b2g"}
            "BitcoinInterest" {$Coin = " -coin bci"}
            "Callisto"        {$Coin = " -coin clo"}
            "DubaiCoin"       {$Coin = " -coin dbix"}
            "Ellaism"         {$Coin = " -coin ella"}
            "Ether1"          {$Coin = " -coin etho"} 
            "EtherCC"         {$Coin = " -coin etcc"} 
            "EtherGem"        {$Coin = " -coin egem"}
            "Ethersocial"     {$Coin = " -coin esn"}
            "EtherZero"       {$Coin = " -coin etz"}
            "Ethereum"        {$Coin = " -coin eth"}
            "EthereumClassic" {$Coin = " -coin etc"}
            "Expanse"         {$Coin = " -coin exp"}
            "Genom"           {$Coin = " -coin gen"}
            "HotelbyteCoin"   {$Coin = " -coin hbc"}
            "Metaverse"       {$Coin = " -coin etp"}
            "Mix"             {$Coin = " -coin mix"} 
            "Moac"            {$Coin = " -coin moac"}
            "Musicoin"        {$Coin = " -coin music"}
            "Nekonium"        {$Coin = " -coin nuko"}
            "Pegascoin"       {$Coin = " -coin pgc"}
            "Pirl"            {$Coin = " -coin pirl"} 
            "Reosc"           {$Coin = " -coin reosc"} 
            "Ubiq"            {$Coin = " -coin ubq"}
            "Victorium"       {$Coin = " -coin vic"}
            "WhaleCoin"       {$Coin = " -coin whale"}
            "Yocoin"          {$Coin = " -coin yoc"}
            default           {$Coin = " -coin auto"}
        }

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Secondary_Algorithm = $_.SecondaryAlgorithm
            $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$($Main_Algorithm_Norm, "$($Secondary_Algorithm_Norm)$(if ($Secondary_Algorithm_Norm -and $_.SecondaryIntensity -gt 0) {"-$($_.SecondaryIntensity)"})" -join '') $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            if ($Secondary_Algorithm_Norm) {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @("$Main_Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @("$(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity})") | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; "$Secondary_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary += " -dcoin $Secondary_Algorithm -dpool $(if ($Pools.$Secondary_Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpass $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -sci $($_.SecondaryIntensity)"})"
                $IntervalMultiplier = 2
                $WarmupTime = 45
                $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0.9 / 100; "$Secondary_Algorithm_Norm" = 0 / 100}
            }
            else {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{"$Main_Algorithm_Norm" = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                $Arguments_Primary += " -gt 0" #Enable auto-tuning
                
                if ($CommonParameters -match " -gt 0" ) {$IntervalMultiplier = 2} else {$IntervalMultiplier = 1}
                $WarmupTime = 30
                $Miner_Fees = [PSCustomObject]@{"$Main_Algorithm_Norm" = 0.65 / 100}

                #TurboKernels
                if ($Miner_Device.Vendor -eq "Advanced Micro Devices, Inc." -and ([math]::Round((10 * ($Miner_Device.OpenCL | Measure-Object GlobalMemSize -Minimum).Minimum / 1GB), 0) / 10) -ge (2 * $MinMemGB)) {
                    # faster AMD "turbo" kernels require twice as much VRAM
                    $TurboKernel = " -clkernel 3"
                }
            }

            [PSCustomObject]@{
                Name               = $Miner_Name
                BaseName           = $Miner_BaseName
                Version            = $Miner_Version
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("-mport -$Miner_Port$(if($Pools.$Main_Algorithm_Norm.Name -eq "NiceHash") {" -proto 4"} else {" -proto 1"}) -pool $(if ($Pools.$Main_Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -wal $($Pools.$Main_Algorithm_Norm.User) -pass $($Pools.$Main_Algorithm_Norm.Pass)$Arguments_Primary$Arguments_Secondary$Coin$Parameters$CommonParameters$TurboKernel -gpus $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.PCIBus_Type_PlatformId_Index + 1)}) -join ',')" -replace "\s+", " ").trim()
                HashRates          = $Miner_HashRates
                API                = "Claymore"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = $Miner_Fees
                IntervalMultiplier = $IntervalMultiplier
                WarmupTime         = $WarmupTime
            }
        }
    }
}
