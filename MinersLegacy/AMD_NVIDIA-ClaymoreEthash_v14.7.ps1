using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\EthDcrMiner64.exe"
$HashSHA256 = "640D067A458117274E4FF64F269082E9CE62AB9D5AC4D60ED177ED97801B4649"
$Uri = "https://github.com/MultiPoolMiner/miner-binaries/releases/download/ethdcrminer64/ClaymoreDual_v14.7.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=1433925.0"

$Miner_Version = Get-MinerVersion $Name
$Miner_BaseName = Get-MinerBaseName $Name
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash2gb
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Blake2s40
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Blake2s60
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80;  Params = ""} #Ethash2gb/Blake2s80
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Decred20
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Decred40
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 70;  Params = ""} #Ethash2gb/Decred70
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred";  SecondaryIntensity = 100; Params = ""} #Ethash2gb/Decred100
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Keccak20
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 30;  Params = ""} #Ethash2gb/Keccak30
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Keccak40
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Lbry40
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Lbry60
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 75;  Params = ""} #Ethash2gb/Lbry75
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 90;  Params = ""} #Ethash2gb/Lbry90
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Pascal20
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Pascal40
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Pascal60
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 80;  Params = ""} #Ethash2gb/Pascal80
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "sia";     SecondaryIntensity = 20;  Params = ""} #Ethash2gb/Sia20
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "sia";     SecondaryIntensity = 40;  Params = ""} #Ethash2gb/Sia40
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "sia";     SecondaryIntensity = 60;  Params = ""} #Ethash2gb/Sia60
        [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "sia";     SecondaryIntensity = 80;  Params = ""} #Ethash2gb/Sia80
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash3gb
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Blake2s20
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Blake2s40
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Blake2s60
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80;  Params = ""} #Ethash3gb/Blake2s80
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Decred40
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  SecondaryIntensity = 70;  Params = ""} #Ethash3gb/Decred70
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred";  SecondaryIntensity = 100; Params = ""} #Ethash3gb/Decred100
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Keccak20
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 30;  Params = ""} #Ethash3gb/Keccak30
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Keccak40
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Lbry40
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Lbry60
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 75;  Params = ""} #Ethash3gb/Lbry75
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 90;  Params = ""} #Ethash3gb/Lbry90
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Pascal20
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Pascal40
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Pascal60
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 80;  Params = ""} #Ethash3gb/Pascal80
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "sia";     SecondaryIntensity = 20;  Params = ""} #Ethash3gb/Sia20
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "sia";     SecondaryIntensity = 40;  Params = ""} #Ethash3gb/Sia40
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "sia";     SecondaryIntensity = 60;  Params = ""} #Ethash3gb/Sia60
        [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "sia";     SecondaryIntensity = 80;  Params = ""} #Ethash3gb/Sia80
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "";        SecondaryIntensity = 00;  Params = ""} #Ethash
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 20;  Params = ""} #Ethash/Blake2s20
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40;  Params = ""} #Ethash/Blake2s40
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60;  Params = ""} #Ethash/Blake2s60
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80;  Params = ""} #Ethash/Blake2s80
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 20;  Params = ""} #Ethash/Decred20
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 40;  Params = ""} #Ethash/Decred40
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 70;  Params = ""} #Ethash/Decred70
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "decred";  SecondaryIntensity = 100; Params = ""} #Ethash/Decred100
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 20;  Params = ""} #Ethash/Keccak20
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 30;  Params = ""} #Ethash/Keccak30
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "keccak";  SecondaryIntensity = 40;  Params = ""} #Ethash/Keccak40
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 40;  Params = ""} #Ethash/Lbry40
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 60;  Params = ""} #Ethash/Lbry60
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 75;  Params = ""} #Ethash/Lbry75
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "lbry";    SecondaryIntensity = 90;  Params = ""} #Ethash/Lbry90
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 20;  Params = ""} #Ethash/Pascal20
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 40;  Params = ""} #Ethash/Pascal40
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 60;  Params = ""} #Ethash/Pascal60
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "pascal";  SecondaryIntensity = 80;  Params = ""} #Ethash/Pascal80
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "sia";     SecondaryIntensity = 20;  Params = ""} #Ethash/Sia20
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "sia";     SecondaryIntensity = 40;  Params = ""} #Ethash/Sia40
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "sia";     SecondaryIntensity = 60;  Params = ""} #Ethash/Sia60
        [PSCustomObject]@{MainAlgorithm = "ethash";    MinMemGB = 4; SecondaryAlgorithm = "sia";     SecondaryIntensity = 80;  Params = ""} #Ethash/Sia80
    )
}

#CommonCommandsAll from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParametersAll = $Miner_Config.CommonParametersAll}
else {$CommonParametersAll = " -dbg -1 -strap 1"}

#CommonCommandsNvidia from config file take precedence
if ($Miner_Config.CommonParametersNvidia) {$CommonParametersNvidia = $Miner_Config.CommonParametersNvidia}
else {$CommonParametersNvidia = " -platform 2"}

#CommonCommandsAmd from config file take precedence
if ($Miner_Config.CommonParametersAmd) {$CommonCommmandAmd = $Miner_Config.CommonParametersAmd}
else {$CommonParametersAmd = " -platform 1 -y 1 -rxboost 1"}

$Devices = @($Devices | Where-Object Type -EQ "GPU")
$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    switch ($_.Vendor) {
        "Advanced Micro Devices, Inc." {$CommonParameters = $CommonParametersAmd + $CommonParametersAll}
        "NVIDIA Corporation" {$CommonParameters = $CommonParametersNvidia + $CommonParametersAll}
        Default {$CommonParameters = $CommonParametersAll}
    }

    #Remove -strap parameter, not all card models support it
    if ($Device.Model_Norm -notmatch "^GTX10.*|^Baffin.*|^Ellesmere.*|^Polaris.*|^Vega.*|^gfx900.*") {
        $CommonParameters = $CommonParameters -replace " -strap [\d,]{1,}"
    }
    
    $Commands | ForEach-Object {$Main_Algorithm_Norm = Get-Algorithm $_.MainAlgorithm; $_} | Where-Object {$Pools.$Main_Algorithm_Norm.Host} | ForEach-Object {
        $Main_Algorithm = $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Secondary_Algorithm = $_.SecondaryAlgorithm
            $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Main_Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$($Main_Algorithm_Norm) $Miner_Device.Type_Vendor_Index
                if ($Miner_Config.Parameters.$Secondary_Algorithm_Norm -and $Secondary_Algorithm_Norm -and $_.SecondaryIntensity -gt 0) {
                    $Parameters += Get-ParameterPerDevice $Miner_Config.Parameters.$($Secondary_Algorithm_Norm) $Miner_Device.Type_Vendor_Index
                }
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            if ($Secondary_Algorithm_Norm) {
                switch ($_.$Secondary_Algorithm_Norm) {
                    "Decred"      {$Secondary_Algorithm = "dcr"}
                    "Lbry"        {$Secondary_Algorithm = "lbc"}
                    "Pascal"      {$Secondary_Algorithm = "pasc"}
                    "SiaClaymore" {$Secondary_Algorithm = "sc"}
                }
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') + @("$Main_Algorithm_Norm$($Secondary_Algorithm_Norm -replace 'Nicehash'<#temp fix#>)") + @("$(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity})") | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary = " -dcoin $Secondary_Algorithm -dpool $($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port) -dwal $($Pools.$Secondary_Algorithm_Norm.User) -dpsw $($Pools.$Secondary_Algorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -dcri $($_.SecondaryIntensity)"})"

                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 3GB}) {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 1 / 100; $Secondary_Algorithm_Norm = 0 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 0 / 100; $Secondary_Algorithm_Norm = 0 / 100}
                }
            }
            else {
                $Miner_Name = (@($Name) + @(($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) -join '_') | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                $Arguments_Secondary = ""

                if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -gt 3GB}) {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 1 / 100}
                }
                else {
                    $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 0 / 100}
                }
            }
            #Avoid DAG switching
            switch ($Main_Algorithm_Norm) {
                "Ethash" {$Allcoins = " -allcoins etc"}
                default  {$Allcoins = " -allcoins 1"}
            }

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) {$Miner_Config = [PSCustomObject]@{DisableDevFeeMining = $Config.DisableDevFeeMining}}
            if ($Miner_Config.DisableDevFeeMining) {
                $NoFee = " -nofee 1"
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 0 / 100}
            }
            else {$NoFee = ""}

            #Remove -strap parameter for Nvidia 1080(Ti) and Titan cards, OhGoAnETHlargementPill is not compatible
            if ($Device.Model -match "GeForce GTX 1080|GeForce GTX 1080 Ti|Nvidia TITAN.*" -and (Get-CIMInstance CIM_Process | Where-Object Processname -like "OhGodAnETHlargementPill*")) {
                $CommonParameters = $CommonParameters -replace " -strap [\d,]{1,}"
            }

            [PSCustomObject]@{
                Name               = $Miner_Name
                BaseName           = $Miner_BaseName
                Version            = $Miner_Version
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("-mport -$Miner_Port -epool $($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port) -ewal $($Pools.$Main_Algorithm_Norm.User) -epsw $($Pools.$Main_Algorithm_Norm.Pass) -allpools 1$Allcoins -esm 3$Arguments_Secondary$Parameters$CommonParameters$NoFee -di $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.PCIBus_Type_Vendor_Index}) -join '')" -replace "\s+", " ").trim()
                HashRates          = $Miner_HashRates
                API                = "Claymore"
                Port               = $Miner_Port
                URI                = $Uri
                Fees               = $Miner_Fees
                IntervalMultiplier = $IntervalMultiplier
                WarmupTime         = 45
            }
        }
    }
}
